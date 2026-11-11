"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Upload } from "tus-js-client";
import { ApiError, api, errorMessage } from "./api";
import type { Episode, VideoUploadTicket } from "./types";

/** Which portal owns the episode: decides the API prefix. */
export type PortalScope = "studio" | "admin";

export type UploadPhase =
  | "idle"
  | "preparing" // asking the API for TUS credentials
  | "uploading"
  | "offline" // paused by a network drop, resumes on `online`
  | "completing" // POST .../video-upload/complete
  | "done"
  | "error"
  | "cancelled";

export interface UploadState {
  phase: UploadPhase;
  sent: number;
  total: number;
  /** Bytes per second, smoothed over the last few seconds. */
  speed: number;
  error: string | null;
  /** API error code, e.g. `video_storage_not_configured`. */
  code: string | null;
  /** True once bytes can go to Bunny: `resume()` continues instead of restarting. */
  resumable: boolean;
}

const IDLE: UploadState = { phase: "idle", sent: 0, total: 0, speed: 0, error: null, code: null, resumable: false };

export const episodeVideoPath = (scope: PortalScope, dramaId: string | number, episodeId: number) =>
  `/${scope}/dramas/${dramaId}/episodes/${episodeId}/video-upload`;

/**
 * Direct-to-Bunny resumable upload for one episode video:
 * 1. POST .../video-upload for a signed TUS ticket,
 * 2. TUS upload straight to Bunny (retries + resumes after network drops),
 * 3. POST .../video-upload/complete, which returns the updated episode.
 *
 * tus-js-client is imported on demand so it never lands in the main bundle.
 */
export function useEpisodeVideoUpload() {
  const [state, setState] = useState<UploadState>(IDLE);
  const upload = useRef<Upload | null>(null);
  const job = useRef<{
    path: string;
    resolve: (e: Episode | null) => void;
    /** Bunny video GUID from the ticket, echoed to /complete. */
    videoId?: string;
  } | null>(null);
  const samples = useRef<{ t: number; b: number }[]>([]);
  const phaseRef = useRef<UploadPhase>("idle");

  const set = useCallback((patch: Partial<UploadState>) => {
    setState((s) => {
      const next = { ...s, ...patch };
      phaseRef.current = next.phase;
      return next;
    });
  }, []);

  const finish = useCallback((episode: Episode | null) => {
    const j = job.current;
    job.current = null;
    upload.current = null;
    j?.resolve(episode);
  }, []);

  const complete = useCallback(async () => {
    const j = job.current;
    if (!j) return;
    set({ phase: "completing", speed: 0 });
    try {
      const ep = await api.post<Episode>(`${j.path}/complete`, j.videoId ? { video_id: j.videoId } : undefined);
      set({ phase: "done" });
      finish(ep ?? null);
    } catch (e) {
      // 409 no_video_upload / video_upload_mismatch: this upload no longer
      // matches the episode, so resuming is pointless; offer a fresh start.
      const stale = e instanceof ApiError && e.status === 409;
      if (stale) upload.current = null;
      set({
        phase: "error",
        error: errorMessage(e), // the API's localized message
        code: e instanceof ApiError ? e.code : null,
        ...(stale ? { resumable: false } : {}),
      });
    }
  }, [finish, set]);

  const start = useCallback(
    async (scope: PortalScope, dramaId: string | number, episodeId: number, file: File): Promise<Episode | null> => {
      upload.current?.abort().catch(() => {});
      finish(null);
      const path = episodeVideoPath(scope, dramaId, episodeId);
      const result = new Promise<Episode | null>((resolve) => {
        job.current = { path, resolve };
      });
      samples.current = [];
      set({ ...IDLE, phase: "preparing", total: file.size });

      let ticket: VideoUploadTicket;
      try {
        const [t, tus] = await Promise.all([api.post<VideoUploadTicket>(path), import("tus-js-client")]);
        ticket = t;
        if (phaseRef.current === "cancelled") return result;
        if (job.current) job.current.videoId = ticket.video_id;

        const up = new tus.Upload(file, {
          endpoint: ticket.tus_endpoint || "https://video.bunnycdn.com/tusupload",
          // Retry transient failures with backoff; a drop that outlasts these
          // switches to "offline" and resumes from the server offset later.
          retryDelays: [0, 1000, 3000, 5000, 10000, 20000, 30000],
          // 50 MB chunks keep progress honest and make resumes cheap.
          chunkSize: 50 * 1024 * 1024,
          headers: {
            AuthorizationSignature: ticket.signature,
            AuthorizationExpire: String(ticket.expires),
            VideoId: ticket.video_id,
            LibraryId: String(ticket.library_id),
          },
          metadata: {
            filetype: file.type || "video/mp4",
            title: ticket.title || file.name,
          },
          // Each ticket targets a fresh Bunny video, so never resume an older
          // upload of the same file from storage.
          storeFingerprintForResuming: false,
          onProgress: (sent, total) => {
            const now = performance.now();
            const s = samples.current;
            s.push({ t: now, b: sent });
            while (s.length > 2 && now - s[0]!.t > 5000) s.shift();
            const first = s[0]!;
            const dt = (now - first.t) / 1000;
            const speed = dt > 0.25 ? Math.max(0, (sent - first.b) / dt) : 0;
            set({ phase: "uploading", sent, total, speed });
          },
          onSuccess: () => {
            void complete();
          },
          onError: (err: Error) => {
            if (phaseRef.current === "cancelled") return;
            samples.current = [];
            if (typeof navigator !== "undefined" && !navigator.onLine) {
              set({ phase: "offline", speed: 0 });
              return;
            }
            set({ phase: "error", speed: 0, error: err.message.split("\n")[0] ?? err.message, code: null });
          },
        });
        upload.current = up;
        set({ phase: "uploading", resumable: true });
        up.start();
      } catch (e) {
        set({ phase: "error", error: errorMessage(e), code: e instanceof ApiError ? e.code : null });
      }
      return result;
    },
    [complete, finish, set],
  );

  /** Resume after an error or network drop (continues from the server offset). */
  const resume = useCallback(() => {
    if (!upload.current) return;
    samples.current = [];
    set({ phase: "uploading", error: null });
    // tus HEADs the upload URL first, so this continues from the bytes Bunny
    // already has (or goes straight to onSuccess -> /complete if all were sent).
    upload.current.start();
  }, [set]);

  const cancel = useCallback(() => {
    set({ phase: "cancelled", speed: 0, resumable: false });
    upload.current?.abort().catch(() => {});
    finish(null);
  }, [finish, set]);

  const reset = useCallback(() => {
    upload.current?.abort().catch(() => {});
    finish(null);
    set(IDLE);
  }, [finish, set]);

  // Auto-resume when the connection returns.
  useEffect(() => {
    if (state.phase !== "offline") return;
    const onOnline = () => resume();
    window.addEventListener("online", onOnline);
    return () => window.removeEventListener("online", onOnline);
  }, [state.phase, resume]);

  const active = ["preparing", "uploading", "offline", "completing"].includes(state.phase);

  // Warn before closing the tab mid-upload.
  useEffect(() => {
    if (!active) return;
    const onBefore = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", onBefore);
    return () => window.removeEventListener("beforeunload", onBefore);
  }, [active]);

  // Stop the transfer if the owner unmounts.
  useEffect(
    () => () => {
      upload.current?.abort().catch(() => {});
      upload.current = null;
    },
    [],
  );

  return { state, active, start, resume, cancel, reset };
}

export function formatBytes(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return "0 MB";
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
  if (n < 1024 * 1024 * 1024) return `${(n / 1024 / 1024).toFixed(1)} MB`;
  return `${(n / 1024 / 1024 / 1024).toFixed(2)} GB`;
}
