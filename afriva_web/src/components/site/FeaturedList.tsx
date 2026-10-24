"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { cn } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { GenreChips, PosterBadge, dramaGenres } from "./PosterCard";

/**
 * Featured block: one large card (left, ~62%) + two stacked cards (right, ~38%).
 * Sets of 3 come from home banners; a text pager below switches sets when there are more.
 */
export function FeaturedList({ dramas }: { dramas: Drama[] }) {
  const pageCount = Math.max(1, Math.ceil(dramas.length / 3));
  const [page, setPage] = useState(1);
  if (!dramas.length) return null;
  const [main, ...side] = dramas.slice((page - 1) * 3, page * 3);

  return (
    <section aria-label="Featured">
      <div className="grid gap-[22px] lg:grid-cols-[62fr_38fr]" aria-live="polite">
        <FeaturedLarge drama={main} priority={page === 1} />
        <div className="grid gap-[22px] sm:grid-cols-2 lg:grid-cols-1 lg:grid-rows-2">
          {side.map((d) => (
            <FeaturedSmall key={d.id} drama={d} />
          ))}
        </div>
      </div>

      {pageCount > 1 && (
        <nav className="mt-5 flex items-center justify-center gap-1 text-sm" aria-label="Featured pages">
          <button
            onClick={() => setPage(page - 1)}
            disabled={page === 1}
            className="px-3 py-1.5 text-text-muted transition hover:text-text disabled:opacity-30"
          >
            Previous
          </button>
          {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
            <button
              key={p}
              onClick={() => setPage(p)}
              aria-current={p === page ? "page" : undefined}
              className={cn("min-w-8 px-2 py-1.5 transition", p === page ? "font-semibold text-primary" : "text-text-muted hover:text-text")}
            >
              {p}
            </button>
          ))}
          <button
            onClick={() => setPage(page + 1)}
            disabled={page === pageCount}
            className="px-3 py-1.5 text-text-muted transition hover:text-text disabled:opacity-30"
          >
            Next
          </button>
        </nav>
      )}
    </section>
  );
}

function FeaturedLarge({ drama: d, priority }: { drama: Drama; priority?: boolean }) {
  return (
    <Link
      href={`/drama/${d.slug}`}
      className="group flex h-[230px] overflow-hidden rounded-[2px] bg-surface sm:h-[360px] lg:h-[530px]"
    >
      <div className="relative aspect-[3/4] h-full shrink-0">
        <PosterBadge badge={d.badge} />
        {d.poster_url && (
          <Image
            src={d.poster_url}
            alt={d.title}
            fill
            priority={priority}
            sizes="(max-width: 640px) 175px, 400px"
            className="object-cover"
          />
        )}
      </div>
      <div className="flex min-w-0 flex-1 flex-col p-4 sm:p-5 lg:p-6">
        <h2 className="line-clamp-2 text-lg font-medium sm:text-2xl leading-tight text-primary lg:text-[30px]">{d.title}</h2>
        <p className="mt-2 text-[15px] text-text lg:text-[17px]">{d.total_episodes} Episodes</p>
        <p className="mt-3 line-clamp-3 text-sm leading-[1.45] text-[#555] sm:line-clamp-5 sm:text-[15px] lg:line-clamp-[8] lg:text-base">{d.synopsis}</p>
        <GenreChips names={dramaGenres(d, 3)} size="md" className="mt-auto hidden pt-4 sm:flex" />
      </div>
    </Link>
  );
}

function FeaturedSmall({ drama: d }: { drama: Drama }) {
  return (
    <Link href={`/drama/${d.slug}`} className="group flex h-[160px] overflow-hidden sm:h-[200px] rounded-[2px] bg-surface lg:h-[254px]">
      <div className="relative aspect-[3/4] h-full shrink-0">
        <PosterBadge badge={d.badge} />
        {d.poster_url && <Image src={d.poster_url} alt={d.title} fill sizes="190px" className="object-cover" />}
      </div>
      <div className="flex min-w-0 flex-1 flex-col p-4 lg:p-5">
        <h3 className="line-clamp-1 text-lg font-medium sm:text-xl leading-tight text-text transition-colors group-hover:text-primary lg:text-[30px]">
          {d.title}
        </h3>
        <p className="mt-2 text-[15px] text-text lg:text-[17px]">{d.total_episodes} Episodes</p>
        <p className="mt-2 line-clamp-1 text-sm leading-[1.45] text-[#555] sm:line-clamp-2 lg:text-base">{d.synopsis}</p>
        <GenreChips names={dramaGenres(d, 1)} size="md" className="mt-auto pt-3" />
      </div>
    </Link>
  );
}
