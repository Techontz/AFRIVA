"use client";

import { useId, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/Button";
import { Pill, Spinner, type Tone } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { cn } from "@/lib/format";
import type { Episode, VideoStatus } from "@/lib/types";
import {
  formatBytes,
  useEpisodeVideoUpload,
  type PortalScope,
  type UploadState,
} from "@/lib/videoUpload";
import { inputClass } from "../ui/Form";

/** Status to display; older APIs without `video_status` fall back to the URL. */
export function episodeVideoStatus(e: Pick<Episode, "video_status" | "video_url">): VideoStatus {
  if (e.video_status && e.video_status !== "none") return e.video_status;
  return e.video_url ? "ready" : "none";
}

/**
 * Studio/admin `video_url` / `thumbnail_url` are raw (unsigned) values for edit
 * forms; anything rendered in <video>/<img> must use the signed preview fields.
 * Older APIs without those fields fall back to the raw value.
 */
export const episodePlaybackUrl = (e: Episode): string | null =>
  e.playback_url !== undefined ? e.playback_url : (e.video_url ?? null);
export const episodeThumbUrl = (e: Episode): string | null =>
  e.thumbnail_preview_url !== undefined ? e.thumbnail_preview_url : (e.thumbnail_url ?? null);

/** True while the list should keep polling for this episode. */
export const isVideoPending = (e: Pick<Episode, "video_status">) =>
  e.video_status === "uploading" || e.video_status === "processing";

const statusTone: Record<VideoStatus, Tone> = {
  none: "neutral",
  uploading: "info",
  processing: "info",
  ready: "success",
  failed: "danger",
};

export function VideoStatusBadge({ episode }: { episode: Pick<Episode, "video_status" | "video_url"> }) {
  const t = useT().portal.video.status;
  const status = episodeVideoStatus(episode);
  return (
    <Pill tone={statusTone[status]} className="normal-case">
      {(status === "uploading" || status === "processing") && <Spinner size={10} />}
      {status === "failed" && <Icon name="alert" size={11} />}
      {t[status]}
    </Pill>
  );
}

export interface EpisodeVideoValue {
  mode: "upload" | "url";
  url: string;
  file: File | null;
}

/**
 * Video source picker for an episode: "Upload video" (direct to Bunny,
 * primary) or "Paste a URL" (manual mp4 / m3u8 link, secondary).
 */
export function EpisodeVideoInput({
  label,
  value,
  onChange,
  episode,
  disabled,
}: {
  label: string;
  value: EpisodeVideoValue;
  onChange: (v: EpisodeVideoValue) => void;
  episode?: Episode | null;
  disabled?: boolean;
}) {
  const id = useId();
  const t = useT().portal.video;
  const hasVideo = !!episode && episodeVideoStatus(episode) !== "none";

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between gap-2">
        <span className="flex items-center gap-2 text-[13px] font-semibold text-text-muted">
          {label}
          {episode && <VideoStatusBadge episode={episode} />}
        </span>
        <div className="flex rounded-full bg-surface-2 p-0.5 text-[11px] font-semibold">
          {(["upload", "url"] as const).map((m) => (
            <button
              key={m}
              type="button"
              disabled={disabled}
              onClick={() => onChange({ ...value, mode: m })}
              className={cn(
                "rounded-full px-2.5 py-1 transition",
                value.mode === m ? "bg-surface text-text shadow" : "text-text-dim hover:text-text",
              )}
            >
              {m === "upload" ? t.upload : t.pasteUrl}
            </button>
          ))}
        </div>
      </div>
      {value.mode === "upload" ? (
        <>
          <label
            htmlFor={id}
            className={cn(
              "flex cursor-pointer items-center gap-3 rounded-xl border border-dashed border-border bg-surface px-3.5 py-3 text-sm text-text-muted transition hover:border-primary hover:text-text",
              disabled && "pointer-events-none opacity-60",
            )}
          >
            <Icon name="upload" size={18} />
            <span className="min-w-0 flex-1 truncate">
              {value.file ? fmt(t.selected, { name: value.file.name, size: formatBytes(value.file.size) }) : t.chooseFile}
            </span>
            {value.file && <span className="shrink-0 text-xs font-semibold text-primary">{t.changeFile}</span>}
            <input
              id={id}
              type="file"
              accept="video/*"
              className="sr-only"
              disabled={disabled}
              onChange={(e) => {
                const f = e.target.files?.[0] ?? null;
                onChange({ ...value, file: f });
                e.target.value = "";
              }}
            />
          </label>
          <p className="text-[11px] leading-relaxed text-text-dim">{hasVideo ? t.replaceHint : t.fileHint}</p>
        </>
      ) : (
        <>
          <input
            type="url"
            placeholder="https://…/episode.mp4"
            className={inputClass}
            value={value.url}
            disabled={disabled}
            onChange={(e) => onChange({ ...value, url: e.target.value })}
          />
          <p className="text-[11px] text-text-dim">{t.urlHint}</p>
        </>
      )}
    </div>
  );
}

/** Progress bar with percent, bytes, speed, and cancel / resume controls. */
export function UploadProgress({
  state,
  onCancel,
  onResume,
  onRetry,
}: {
  state: UploadState;
  onCancel: () => void;
  onResume: () => void;
  onRetry?: () => void;
}) {
  const t = useT().portal.video;
  const pct = state.total ? Math.min(100, Math.floor((state.sent / state.total) * 100)) : 0;
  const busy = state.phase === "preparing" || state.phase === "uploading" || state.phase === "offline" || state.phase === "completing";
  const label =
    state.phase === "preparing"
      ? t.preparing
      : state.phase === "uploading"
        ? fmt(t.uploading, { pct })
        : state.phase === "offline"
          ? t.offline
          : state.phase === "completing"
            ? t.completing
            : state.phase === "done"
              ? t.done
              : state.phase === "cancelled"
                ? t.cancelled
                : t.failed;
  // Prefer the API's localized message; our own text is only a fallback.
  const errorText = state.error || (state.code === "video_storage_not_configured" ? t.notConfigured : null);

  return (
    <div
      className={cn(
        "rounded-xl border p-3.5",
        state.phase === "error" ? "border-danger/30 bg-danger/10" : "border-border bg-surface-2/50",
      )}
      aria-live="polite"
    >
      <div className="mb-2 flex items-center justify-between gap-3 text-xs">
        <span className={cn("font-semibold", state.phase === "error" ? "text-danger" : state.phase === "done" ? "text-success" : "text-text")}>
          {label}
        </span>
        {state.phase === "uploading" && state.speed > 0 && (
          <span className="shrink-0 tabular-nums text-text-muted">{fmt(t.speed, { speed: formatBytes(state.speed) })}</span>
        )}
      </div>
      <div
        className="h-2 overflow-hidden rounded-full bg-surface-2"
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div
          className={cn(
            "h-full rounded-full transition-all duration-300",
            state.phase === "error" ? "bg-danger" : state.phase === "done" ? "bg-success" : "bg-primary",
            state.phase === "offline" && "animate-pulse",
          )}
          style={{ width: `${state.phase === "done" || state.phase === "completing" ? 100 : pct}%` }}
        />
      </div>
      <div className="mt-2 flex items-center justify-between gap-2 text-[11px] text-text-dim">
        <span className="tabular-nums">
          {state.total > 0 && fmt(t.progress, { sent: formatBytes(state.sent), total: formatBytes(state.total) })}
        </span>
        {busy && state.phase !== "completing" && <span>{t.keepOpen}</span>}
      </div>
      {errorText && state.phase === "error" && <p className="mt-2 text-xs text-danger">{errorText}</p>}
      {(busy || state.phase === "error") && (
        <div className="mt-3 flex flex-wrap justify-end gap-2">
          {state.phase !== "completing" && (
            <Button type="button" size="sm" variant="ghost" onClick={onCancel}>
              {t.cancel}
            </Button>
          )}
          {(state.phase === "error" || state.phase === "offline") && state.resumable && (
            <Button type="button" size="sm" onClick={onResume}>
              <Icon name="refresh" size={14} /> {t.resume}
            </Button>
          )}
          {state.phase === "error" && !state.resumable && onRetry && state.code !== "video_storage_not_configured" && (
            <Button type="button" size="sm" onClick={onRetry}>
              <Icon name="refresh" size={14} /> {t.retry}
            </Button>
          )}
        </div>
      )}
    </div>
  );
}

/** Stand-alone upload (or re-upload) for an existing episode, opened from the episode list. */
export function VideoUploadModal({
  episode,
  scope,
  dramaId,
  onClose,
  onUploaded,
}: {
  episode: Episode | null;
  scope: PortalScope;
  dramaId: string | number;
  onClose: () => void;
  onUploaded: (e: Episode | null) => void;
}) {
  const t = useT().portal.video;
  const tc = useT().common;
  const [file, setFile] = useState<File | null>(null);
  const up = useEpisodeVideoUpload();

  const run = async () => {
    if (!episode || !file) return;
    const saved = await up.start(scope, dramaId, episode.id, file);
    if (saved) {
      toast.success(t.done);
      onUploaded(saved);
    }
  };

  const close = () => {
    if (up.active) up.cancel();
    up.reset();
    setFile(null);
    onClose();
  };

  const started = up.state.phase !== "idle";

  return (
    <Modal open={!!episode} onClose={up.active ? () => {} : close} title={episode ? fmt(t.uploadFor, { n: episode.number }) : ""}>
      {episode && (
        <div className="grid gap-4">
          {!started || up.state.phase === "cancelled" ? (
            <EpisodeVideoInput
              label={t.upload}
              value={{ mode: "upload", url: "", file }}
              onChange={(v) => setFile(v.file)}
              episode={episode}
            />
          ) : (
            <UploadProgress state={up.state} onCancel={up.cancel} onResume={up.resume} onRetry={run} />
          )}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={close} disabled={up.active}>
              {up.state.phase === "done" ? tc.actions.close : tc.actions.cancel}
            </Button>
            {(!started || up.state.phase === "cancelled") && (
              <Button type="button" onClick={run} disabled={!file}>
                <Icon name="upload" size={16} /> {t.start}
              </Button>
            )}
          </div>
        </div>
      )}
    </Modal>
  );
}
