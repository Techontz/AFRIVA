"use client";

import { useCallback, useEffect, useRef, type Ref, type VideoHTMLAttributes } from "react";

/** True for HLS playlists, including signed URLs where `.m3u8` is not at the end. */
export function isHlsUrl(url: string | null | undefined): boolean {
  return !!url && /\.m3u8(?:$|[?#/&])/i.test(url);
}

type Props = Omit<VideoHTMLAttributes<HTMLVideoElement>, "src"> & {
  src: string;
  ref?: Ref<HTMLVideoElement>;
  /** Fired when playback cannot recover (fatal HLS error). */
  onFatalError?: () => void;
  /** Wanted rendition by its short side (720 = 720p); null or undefined = Auto. */
  quality?: number | null;
  /** Available renditions (short side, highest first) once the HLS manifest is read. */
  onQualities?: (qualities: number[]) => void;
  /** Rendition currently playing (short side), when known. */
  onActiveQuality?: (quality: number | null) => void;
};

/** "720p" for both 1280x720 and 720x1280. */
const shortSide = (w?: number, h?: number) => Math.min(w || Infinity, h || Infinity);

/** Variant playlists of an HLS master: short side -> absolute URL (signed path prefix is kept). */
function parseMaster(text: string, base: string): Map<number, string> {
  const out = new Map<number, string>();
  const lines = text.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (!line.startsWith("#EXT-X-STREAM-INF")) return;
    const res = /RESOLUTION=(\d+)x(\d+)/.exec(line);
    const uri = lines.slice(i + 1).find((l) => l.trim() && !l.startsWith("#"));
    if (!res || !uri) return;
    const q = shortSide(Number(res[1]), Number(res[2]));
    if (Number.isFinite(q) && !out.has(q)) out.set(q, new URL(uri.trim(), base).href);
  });
  return out;
}

/** Swap the <video> source and resume at the same position. */
function swapSource(video: HTMLVideoElement, url: string) {
  const time = video.currentTime;
  const playing = !video.paused;
  video.src = url;
  video.addEventListener(
    "loadedmetadata",
    () => {
      if (time) video.currentTime = time;
      if (playing) video.play().catch(() => {});
    },
    { once: true },
  );
}

/**
 * `<video>` that also plays HLS:
 * - mp4 and other files: plain `src`, exactly like before;
 * - `.m3u8` on Safari / iOS (native HLS): plain `src`;
 * - `.m3u8` elsewhere: hls.js, imported only when needed so the main bundle
 *   stays lean. The instance is destroyed on src change and unmount.
 *
 * With `preload="metadata"`/`"none"` hls.js only fetches the playlist and
 * starts downloading segments on the first `play`, so off-screen feed items
 * stay cheap.
 */
export function StreamVideo({ src, ref, onFatalError, quality, onQualities, onActiveQuality, ...rest }: Props) {
  const el = useRef<HTMLVideoElement | null>(null);
  const hls = isHlsUrl(src);
  const lazy = rest.preload === "none" || rest.preload === "metadata";
  const lazyRef = useRef(lazy);
  const fatalRef = useRef(onFatalError);
  const qualityRef = useRef(quality ?? null);
  const callbacks = useRef({ onQualities, onActiveQuality });
  /** Applies a quality to whichever engine is active (set by the load effect). */
  const applyRef = useRef<((q: number | null) => void) | null>(null);
  useEffect(() => {
    lazyRef.current = lazy;
    fatalRef.current = onFatalError;
    callbacks.current = { onQualities, onActiveQuality };
  }, [lazy, onFatalError, onQualities, onActiveQuality]);

  useEffect(() => {
    qualityRef.current = quality ?? null;
    applyRef.current?.(quality ?? null);
  }, [quality]);

  const setRef = useCallback(
    (node: HTMLVideoElement | null) => {
      el.current = node;
      if (typeof ref === "function") ref(node);
      else if (ref) (ref as { current: HTMLVideoElement | null }).current = node;
    },
    [ref],
  );

  useEffect(() => {
    const video = el.current;
    if (!video || !hls) return;

    let cancelled = false;
    let destroy: (() => void) | null = null;

    if (video.canPlayType("application/vnd.apple.mpegurl")) {
      // Native HLS (Safari / iOS): Auto plays the master; a fixed quality plays its variant playlist.
      let variants = new Map<number, string>();
      let current: string = src;
      video.src = src;
      // The decoded frame size tells which rendition Auto picked.
      const onResize = () => {
        const q = shortSide(video.videoWidth, video.videoHeight);
        if (Number.isFinite(q)) callbacks.current.onActiveQuality?.(q);
      };
      video.addEventListener("resize", onResize);
      const apply = (q: number | null) => {
        const url = (q && variants.get(q)) || src;
        if (url === current) return;
        current = url;
        swapSource(video, url);
      };
      fetch(src)
        .then((r) => (r.ok ? r.text() : ""))
        .then((text) => {
          if (cancelled || !text) return;
          variants = parseMaster(text, src);
          callbacks.current.onQualities?.([...variants.keys()].sort((a, b) => b - a));
          applyRef.current = apply;
          if (qualityRef.current) apply(qualityRef.current);
        })
        .catch(() => {});
      return () => {
        cancelled = true;
        applyRef.current = null;
        video.removeEventListener("resize", onResize);
        video.removeAttribute("src");
        video.load();
      };
    }

    import("hls.js")
      .then(({ default: Hls }) => {
        if (cancelled) return;
        if (!Hls.isSupported()) {
          video.src = src; // last resort; lets the browser report the error
          return;
        }
        const instance = new Hls({
          startLevel: -1, // auto: pick from measured bandwidth
          capLevelToPlayerSize: true,
          autoStartLoad: !lazyRef.current,
          maxBufferLength: 30,
          backBufferLength: 30,
        });
        let started = !lazyRef.current;
        const onPlay = () => {
          if (started) return;
          started = true;
          instance.startLoad(-1);
        };
        const levelIndex = (q: number | null) =>
          q ? instance.levels.findIndex((l) => shortSide(l.width, l.height) === q) : -1;
        instance.on(Hls.Events.MANIFEST_PARSED, () => {
          const qs = [...new Set(instance.levels.map((l) => shortSide(l.width, l.height)).filter(Number.isFinite))];
          callbacks.current.onQualities?.(qs.sort((a, b) => b - a));
          const idx = levelIndex(qualityRef.current);
          if (idx >= 0) {
            instance.startLevel = idx;
            instance.currentLevel = idx;
          }
          applyRef.current = (q) => {
            // currentLevel flushes the buffer and reloads at the current position.
            instance.currentLevel = levelIndex(q);
          };
        });
        // Report the rendition actually on screen (the fragment being played).
        instance.on(Hls.Events.FRAG_CHANGED, (_evt, data) => {
          const l = instance.levels[data.frag.level];
          callbacks.current.onActiveQuality?.(l ? shortSide(l.width, l.height) : null);
        });
        let mediaRecoveries = 0;
        instance.on(Hls.Events.ERROR, (_evt, data) => {
          if (!data.fatal) return;
          if (data.type === Hls.ErrorTypes.NETWORK_ERROR) {
            instance.startLoad();
          } else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && mediaRecoveries < 2) {
            mediaRecoveries++;
            instance.recoverMediaError();
          } else {
            fatalRef.current?.();
          }
        });
        video.addEventListener("play", onPlay);
        instance.loadSource(src);
        instance.attachMedia(video);
        // play() may have been requested before hls.js finished loading.
        if (!started && (!video.paused || video.autoplay)) onPlay();
        destroy = () => {
          applyRef.current = null;
          video.removeEventListener("play", onPlay);
          instance.destroy();
        };
      })
      .catch(() => {
        if (!cancelled) fatalRef.current?.();
      });

    return () => {
      cancelled = true;
      destroy?.();
      destroy = null;
    };
  }, [src, hls]);

  return <video ref={setRef} src={hls ? undefined : src} {...rest} />;
}
