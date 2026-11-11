"use client";

import { useCallback, useRef, useState, useSyncExternalStore, type KeyboardEvent, type PointerEvent, type TouchEvent } from "react";
import { Icon } from "@/components/ui/Icon";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { fmt } from "@/i18n/format";
import { cn } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { BadgeText } from "../SiteLabels";

export type HeroLabels = Dictionary["site"]["hero"];
export interface HeroProps {
  dramas: Drama[];
  labels: HeroLabels;
}

/** Time each slide stays up before auto-advancing. */
export const HERO_INTERVAL = 5000;

export const playHref = (d: Drama) => `/drama/${d.slug}/ep/1`;
export const detailsHref = (d: Drama) => `/drama/${d.slug}`;

const REDUCED = "(prefers-reduced-motion: reduce)";
function subscribeReduced(cb: () => void) {
  const mq = window.matchMedia(REDUCED);
  mq.addEventListener("change", cb);
  return () => mq.removeEventListener("change", cb);
}

/**
 * Slider state shared by the hero variants: active index (plus the previous one, for wrap detection),
 * pause on mouse hover / touch, swipe and arrow-key navigation. Auto-advance is driven by the
 * progress bar's CSS animation ending (see <ProgressFill/>), so the bar and the timer never drift
 * and pausing the animation pauses the timer. Autoplay is off for prefers-reduced-motion.
 */
export function useHeroCarousel(count: number) {
  const [{ index, prev }, setState] = useState({ index: 0, prev: 0 });
  const [hover, setHover] = useState(false);
  const [touching, setTouching] = useState(false);
  // Server snapshot "reduced" so autoplay only starts once the client knows the real preference.
  const reduced = useSyncExternalStore(subscribeReduced, () => window.matchMedia(REDUCED).matches, () => true);
  const touchStart = useRef<{ x: number; y: number } | null>(null);

  const go = useCallback(
    (i: number) => setState((s) => ({ index: ((i % count) + count) % count, prev: s.index })),
    [count],
  );
  const next = useCallback(() => go(index + 1), [go, index]);
  const previous = useCallback(() => go(index - 1), [go, index]);

  const autoplay = count > 1 && !reduced;
  const paused = !autoplay || hover || touching;

  const rootProps = {
    onPointerEnter: (e: PointerEvent) => e.pointerType === "mouse" && setHover(true),
    onPointerLeave: (e: PointerEvent) => e.pointerType === "mouse" && setHover(false),
    onTouchStart: (e: TouchEvent) => {
      const t = e.touches[0];
      touchStart.current = { x: t.clientX, y: t.clientY };
      setTouching(true);
    },
    onTouchEnd: (e: TouchEvent) => {
      const s = touchStart.current;
      const t = e.changedTouches[0];
      touchStart.current = null;
      setTouching(false);
      if (!s || !t || count < 2) return;
      const dx = t.clientX - s.x;
      const dy = t.clientY - s.y;
      if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy) * 1.2) {
        if (dx < 0) next();
        else previous();
      }
    },
    onTouchCancel: () => {
      touchStart.current = null;
      setTouching(false);
    },
    onKeyDown: (e: KeyboardEvent) => {
      if (e.key === "ArrowRight") next();
      else if (e.key === "ArrowLeft") previous();
    },
  };

  return { index, prev, go, next, previous, paused, autoplay, rootProps };
}

/** Signed circular distance from the active slide, in the range (-count/2, count/2]. */
export function circularOffset(i: number, active: number, count: number) {
  let off = (((i - active) % count) + count) % count;
  if (off > count / 2) off -= count;
  return off;
}

const KEYFRAMES = "@keyframes afriva-hero-fill{from{transform:scaleX(0)}to{transform:scaleX(1)}}";

/**
 * Fills its (relative, overflow-hidden) parent left to right over HERO_INTERVAL and advances the
 * slider when done. Re-keyed on every slide change so the animation restarts.
 */
export function ProgressFill({
  index,
  paused,
  autoplay,
  onDone,
  className,
}: {
  index: number;
  paused: boolean;
  autoplay: boolean;
  onDone: () => void;
  className?: string;
}) {
  return (
    <>
      <style href="afriva-hero-fill" precedence="default">
        {KEYFRAMES}
      </style>
      <span
        key={index}
        aria-hidden
        onAnimationEnd={autoplay ? onDone : undefined}
        className={cn("absolute inset-0 origin-left bg-primary", className)}
        style={
          autoplay
            ? { animation: `afriva-hero-fill ${HERO_INTERVAL}ms linear forwards`, animationPlayState: paused ? "paused" : "running" }
            : undefined
        }
      />
    </>
  );
}

/** Pill dots; the active one stretches and fills with progress. */
export function HeroDots({
  count,
  index,
  go,
  paused,
  autoplay,
  next,
  labels,
  className,
}: {
  count: number;
  index: number;
  go: (i: number) => void;
  paused: boolean;
  autoplay: boolean;
  next: () => void;
  labels: HeroLabels;
  className?: string;
}) {
  if (count < 2) return null;
  return (
    <div className={cn("flex items-center justify-center gap-2", className)}>
      {Array.from({ length: count }, (_, i) => (
        <button
          key={i}
          type="button"
          onClick={() => go(i)}
          aria-label={fmt(labels.goTo, { n: i + 1 })}
          aria-current={i === index ? "true" : undefined}
          className="group/dot flex h-6 items-center"
        >
          <span
            className={cn(
              "relative block h-1.5 overflow-hidden rounded-full transition-all duration-500 ease-brand",
              i === index ? "w-9 bg-text/25" : "w-1.5 bg-text/35 group-hover/dot:bg-text/60",
            )}
          >
            {i === index && <ProgressFill index={index} paused={paused} autoplay={autoplay} onDone={next} className="rounded-full" />}
          </span>
        </button>
      ))}
    </div>
  );
}

/** Round glassy arrow button (desktop only). */
export function HeroArrow({
  dir,
  onClick,
  label,
  className,
}: {
  dir: "left" | "right";
  onClick: () => void;
  label: string;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        "hidden size-12 items-center justify-center rounded-full bg-black/50 text-white backdrop-blur-xl transition hover:bg-black/75 lg:flex",
        className,
      )}
    >
      <Icon name={dir === "left" ? "chevron-left" : "chevron-right"} size={22} strokeWidth={2.2} />
    </button>
  );
}

const badgeTone = {
  hot: "bg-primary text-white",
  new: "bg-white text-black",
  vip: "bg-black/80 text-white ring-1 ring-white/30",
} as const;

export function HeroBadge({ badge, className }: { badge: Drama["badge"]; className?: string }) {
  if (!badge) return null;
  return (
    <span className={cn("inline-flex items-center rounded px-2 py-0.5 text-[11px] font-extrabold uppercase tracking-wider", badgeTone[badge], className)}>
      <BadgeText badge={badge} />
    </span>
  );
}

/** Separator dot for meta rows. */
export function Dot() {
  return <span aria-hidden className="size-1 shrink-0 rounded-full bg-current opacity-50" />;
}
