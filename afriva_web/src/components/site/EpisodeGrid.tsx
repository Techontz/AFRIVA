"use client";

import Link from "next/link";
import { useState } from "react";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
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

/** Range tabs (1-30, 31-60...) + numbered episode buttons. */
export function EpisodeGrid({
  slug,
  episodes,
  current,
  onSelect,
}: {
  slug: string;
  episodes: Episode[];
  current?: number;
  onSelect?: (ep: Episode) => void;
}) {
  const sorted = [...episodes].sort((a, b) => a.number - b.number);
  const maxNumber = sorted.length ? sorted[sorted.length - 1]!.number : 0;
  const ranges = episodeRanges(maxNumber);
  const initialRange = current ? Math.floor((current - 1) / RANGE) : 0;
  const [rangeIdx, setRangeIdx] = useState(initialRange);
  const t = useT().site.episodes;
  const range = ranges[Math.min(rangeIdx, ranges.length - 1)] ?? { from: 1, to: RANGE };
  const visible = sorted.filter((e) => e.number >= range.from && e.number <= range.to);

  if (!sorted.length) {
    return <p className="py-6 text-center text-sm text-text-dim">{t.comingSoon}</p>;
  }

  return (
    <div>
      {ranges.length > 1 && (
        <div className="scrollbar-none mb-4 flex gap-2 overflow-x-auto" role="tablist" aria-label={t.ranges}>
          {ranges.map((r, i) => (
            <button
              key={r.from}
              role="tab"
              aria-selected={i === rangeIdx}
              onClick={() => setRangeIdx(i)}
              className={cn(
                "shrink-0 rounded-full px-4 py-1.5 text-[13px] font-semibold transition-colors",
                i === rangeIdx ? "bg-text text-bg" : "bg-text/10 text-text-muted hover:text-text",
              )}
            >
              {r.from}-{r.to}
            </button>
          ))}
        </div>
      )}
      <div className="grid grid-cols-[repeat(auto-fill,minmax(56px,1fr))] gap-2">
        {visible.map((ep) => {
          const locked = isLocked(ep);
          const active = ep.number === current;
          const cls = cn(
            "relative flex h-14 flex-col items-center justify-center rounded-xl text-[15px] font-semibold transition-colors duration-150",
            active
              ? "bg-primary text-white"
              : locked
                ? "bg-text/[0.05] text-text-muted hover:bg-text/10"
                : "bg-text/10 text-text hover:bg-text/15",
          );
          const inner = (
            <>
              {ep.number}
              {ep.is_free && !active && <span className="mt-0.5 text-[10px] font-medium leading-none text-text-muted">{t.free}</span>}
              {!ep.is_free && (
                <span
                  className={cn("absolute right-1 top-1", active ? "text-white" : locked ? "text-text-dim" : "text-primary")}
                  aria-label={locked ? t.locked : t.vipUnlocked}
                >
                  <Icon name={locked ? "lock" : "crown"} size={11} strokeWidth={2.2} />
                </span>
              )}
            </>
          );
          return onSelect ? (
            <button
              key={ep.id}
              onClick={() => onSelect(ep)}
              aria-current={active ? "true" : undefined}
              aria-label={fmt(locked ? t.labelLocked : t.label, { n: ep.number })}
              className={cls}
            >
              {inner}
            </button>
          ) : (
            <Link
              key={ep.id}
              href={`/drama/${slug}/ep/${ep.number}`}
              aria-label={fmt(locked ? t.labelLocked : t.label, { n: ep.number })}
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
