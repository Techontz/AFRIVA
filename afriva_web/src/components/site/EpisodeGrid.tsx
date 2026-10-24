"use client";

import Link from "next/link";
import { useState } from "react";
import { cn } from "@/lib/format";
import type { Episode } from "@/lib/types";
import { Icon } from "../ui/Icon";

export const RANGE = 30;

export function episodeRanges(total: number) {
  const ranges: { from: number; to: number }[] = [];
  for (let from = 1; from <= Math.max(total, 1); from += RANGE) ranges.push({ from, to: Math.min(from + RANGE - 1, total) });
  return ranges;
}

export function isLocked(ep: Episode) {
  return !ep.is_free && !ep.is_unlocked;
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
  const sorted = [...episodes].sort((a, b) => a.number - b.number);
  const maxNumber = sorted.length ? sorted[sorted.length - 1]!.number : 0;
  const ranges = episodeRanges(maxNumber);
  const initialRange = current ? Math.floor((current - 1) / RANGE) : 0;
  const [rangeIdx, setRangeIdx] = useState(initialRange);
  const range = ranges[Math.min(rangeIdx, ranges.length - 1)] ?? { from: 1, to: RANGE };
  const visible = sorted.filter((e) => e.number >= range.from && e.number <= range.to);

  if (!sorted.length) {
    return <p className="py-6 text-center text-sm text-text-dim">Episodes are coming soon.</p>;
  }

  return (
    <div>
      {ranges.length > 1 && (
        <div className="scrollbar-none mb-4 flex gap-1 overflow-x-auto border-b border-border" role="tablist" aria-label="Episode ranges">
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
          const cls = cn(
            "relative grid aspect-square place-items-center rounded-lg text-sm font-bold transition-all duration-150",
            active
              ? "bg-primary text-white"
              : "bg-surface text-text hover:bg-surface-2",
          );
          const inner = (
            <>
              {ep.number}
              {!ep.is_free && (
                <span
                  className={cn(
                    "absolute right-0.5 top-0.5 grid h-4 w-4 place-items-center rounded",
                    locked ? "text-text-dim" : "text-primary",
                  )}
                  aria-label={locked ? "Locked" : "VIP unlocked"}
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
              aria-label={`Episode ${ep.number}${locked ? " (locked)" : ""}`}
              className={cls}
            >
              {inner}
            </button>
          ) : (
            <Link
              key={ep.id}
              href={`/drama/${slug}/ep/${ep.number}`}
              aria-label={`Episode ${ep.number}${locked ? " (locked)" : ""}`}
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
