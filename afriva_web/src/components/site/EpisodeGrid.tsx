"use client";

import Link from "next/link";
import { useState } from "react";
import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { Episode } from "@/lib/types";
import { Icon } from "../ui/Icon";

export const RANGE = 30;

export function episodeRanges(total: number) {
  const ranges: { from: number; to: number }[] = [];
  for (let from = 1; from <= Math.max(total, 1); from += RANGE) ranges.push({ from, to: Math.min(from + RANGE - 1, total) });
  return ranges;
}

export function isLocked(ep: Episode) {
  if (ep.access) return ep.access === "locked";
  return !ep.is_free && !ep.is_unlocked;
}

/** Short label shown on every episode before it is tapped (scope §02): free, coin price or VIP. */
export function episodeAccessLabel(ep: Episode, t: (s: string, v?: Record<string, string | number>) => string): string | null {
  if (ep.is_free) return t("Free");
  if (!isLocked(ep)) return null;
  if (ep.vip_only || !ep.price_coins) return "VIP";
  return t("{n} coins", { n: ep.price_coins });
}

/** Range tabs (1-30, 31-60…) + numbered episode buttons. */
export function EpisodeGrid({
  slug,
  episodes,
  current,
  onSelect,
  compact,
}: {
  slug: string;
  episodes: Episode[];
  current?: number;
  onSelect?: (ep: Episode) => void;
  compact?: boolean;
}) {
  const t = useT();
  const sorted = [...episodes].sort((a, b) => a.number - b.number);
  const maxNumber = sorted.length ? sorted[sorted.length - 1]!.number : 0;
  const ranges = episodeRanges(maxNumber);
  const initialRange = current ? Math.floor((current - 1) / RANGE) : 0;
  const [rangeIdx, setRangeIdx] = useState(initialRange);
  const range = ranges[Math.min(rangeIdx, ranges.length - 1)] ?? { from: 1, to: RANGE };
  const visible = sorted.filter((e) => e.number >= range.from && e.number <= range.to);

  if (!sorted.length) {
    return <p className="py-6 text-center text-sm text-text-dim">{t("Episodes are coming soon.")}</p>;
  }

  return (
    <div>
      {ranges.length > 1 && (
        <div className="scrollbar-none mb-4 flex gap-1 overflow-x-auto border-b border-border" role="tablist" aria-label={t("Episode ranges")}>
          {ranges.map((r, i) => (
            <button
              key={r.from}
              role="tab"
              aria-selected={i === rangeIdx}
              onClick={() => setRangeIdx(i)}
              className={cn(
                "relative shrink-0 px-3 pb-2.5 pt-1 text-[13px] font-bold transition-colors",
                i === rangeIdx ? "text-text" : "text-text-dim hover:text-text-muted",
              )}
            >
              {r.from}-{r.to}
              {i === rangeIdx && <span className="absolute inset-x-2 bottom-0 h-0.5 rounded-full bg-primary" />}
            </button>
          ))}
        </div>
      )}
      <div className={cn("grid gap-2", compact ? "grid-cols-5 sm:grid-cols-6" : "grid-cols-5 sm:grid-cols-8 md:grid-cols-10 lg:grid-cols-12 xl:grid-cols-15")}>
        {visible.map((ep) => {
          const locked = isLocked(ep);
          const active = ep.number === current;
          const label = episodeAccessLabel(ep, t);
          const cls = cn(
            "relative flex aspect-square flex-col items-center justify-center rounded-lg text-sm font-bold transition-all duration-150",
            active
              ? "bg-primary text-white"
              : "bg-surface text-text hover:bg-surface-2",
          );
          const inner = (
            <>
              {ep.number}
              {label && !active && (
                <span
                  className={cn(
                    "mt-0.5 max-w-full truncate px-0.5 text-[9px] font-bold leading-none",
                    ep.is_free ? "text-success" : "text-text-dim",
                  )}
                >
                  {label}
                </span>
              )}
              {!ep.is_free && (
                <span
                  className={cn(
                    "absolute right-0.5 top-0.5 grid h-4 w-4 place-items-center rounded",
                    locked ? "text-text-dim" : "text-primary",
                  )}
                  aria-label={locked ? t("Locked") : t("VIP unlocked")}
                >
                  <Icon name={locked ? "lock" : "crown"} size={11} strokeWidth={2.2} />
                </span>
              )}
              {active && (
                <span className="absolute bottom-1 flex gap-[2px]" aria-hidden="true">
                  {[0, 1, 2].map((b) => (
                    <span key={b} className="h-1.5 w-[2px] animate-pulse rounded bg-white" style={{ animationDelay: `${b * 150}ms` }} />
                  ))}
                </span>
              )}
            </>
          );
          return onSelect ? (
            <button
              key={ep.id}
              onClick={() => onSelect(ep)}
              aria-current={active ? "true" : undefined}
              aria-label={label ? t("Episode {n} ({label})", { n: ep.number, label }) : t("Episode {n}", { n: ep.number })}
              className={cls}
            >
              {inner}
            </button>
          ) : (
            <Link
              key={ep.id}
              href={`/drama/${slug}/ep/${ep.number}`}
              aria-label={label ? t("Episode {n} ({label})", { n: ep.number, label }) : t("Episode {n}", { n: ep.number })}
              className={cls}
            >
              {inner}
            </Link>
          );
        })}
      </div>
    </div>
  );
}
