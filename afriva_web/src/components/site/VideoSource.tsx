"use client";

import { forwardRef, useEffect, useImperativeHandle, useRef, type VideoHTMLAttributes } from "react";
import type { VideoSource } from "@/lib/types";

/** Source from a bare URL (trailers): HLS when the path ends in .m3u8, else MP4. */
export function sourceFromUrl(url: string): VideoSource {
  const path = url.split("?")[0]!.toLowerCase();
  return { quality: "auto", label: "Auto", url, type: path.endsWith(".m3u8") ? "hls" : "mp4" };
}

function nativeHls(video: HTMLVideoElement) {
  return video.canPlayType("application/vnd.apple.mpegurl") !== "";
}

/**
 * Attach a source to a <video>: hls.js for HLS in browsers without native HLS (Chrome, Firefox),
 * native HLS on Safari/iOS, and a plain src for MP4. `startAt` (read when the source attaches)
 * seeks once metadata is loaded, which is how resume and quality switching keep their position.
 */
export function useVideoSource(
  videoRef: React.RefObject<HTMLVideoElement | null>,
  source: VideoSource | null | undefined,
  { startAt = 0, onFatalError }: { startAt?: number; onFatalError?: (code: string) => void } = {},
) {
  const startRef = useRef(startAt);
  const errorRef = useRef(onFatalError);
  // Declared before the attach effect, so it runs first and the attach sees the latest values.
  useEffect(() => {
    startRef.current = startAt;
    errorRef.current = onFatalError;
  });
  const url = source?.url ?? null;
  const type = source?.type ?? "mp4";

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !url) return;
    let destroyed = false;
    let hls: { destroy: () => void } | null = null;

    const seekOnce = () => {
      const t = startRef.current;
      if (t > 0 && Number.isFinite(video.duration) && t < video.duration - 1) video.currentTime = t;
    };
    video.addEventListener("loadedmetadata", seekOnce, { once: true });

    if (type === "hls" && !nativeHls(video)) {
      import("hls.js").then(({ default: Hls }) => {
        if (destroyed) return;
        if (!Hls.isSupported()) {
          video.src = url;
          return;
        }
        const instance = new Hls({ capLevelToPlayerSize: true });
        instance.on(Hls.Events.ERROR, (_e, data) => {
          if (data.fatal) errorRef.current?.(String(data.details ?? data.type));
        });
        instance.loadSource(url);
        instance.attachMedia(video);
        hls = instance;
      }, () => {
        if (!destroyed) video.src = url;
      });
    } else {
      video.src = url;
    }

    return () => {
      destroyed = true;
      video.removeEventListener("loadedmetadata", seekOnce);
      hls?.destroy();
      video.removeAttribute("src");
      video.load();
    };
  }, [videoRef, url, type]);
}

/** <video> that plays any VideoSource (used for trailers). */
export const SourceVideo = forwardRef<
  HTMLVideoElement,
  Omit<VideoHTMLAttributes<HTMLVideoElement>, "src"> & { source: VideoSource | null; startAt?: number; onFatalError?: (code: string) => void }
>(function SourceVideo({ source, startAt, onFatalError, ...props }, ref) {
  const inner = useRef<HTMLVideoElement>(null);
  useImperativeHandle(ref, () => inner.current as HTMLVideoElement);
  useVideoSource(inner, source, { startAt, onFatalError });
  return <video ref={inner} {...props} />;
});
