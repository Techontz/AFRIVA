import Image from "next/image";
import Link from "next/link";
import { fmt } from "@/i18n/format";
import { getDict } from "@/i18n/server";
import { cn, formatCompact } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { dramaGenres, genreName } from "./PosterCard";

export async function RankingItem({ drama, rank, large }: { drama: Drama; rank: number; large?: boolean }) {
  const t = (await getDict()).site.rankings;
  const dict = await getDict();
  const tags = dramaGenres(drama, 2).map((name) => genreName(name, dict.site.card.categories));
  return (
    <Link
      href={`/drama/${drama.slug}`}
      className="group flex items-center gap-3 rounded-2xl p-2 transition-colors duration-200 hover:bg-text/5 sm:gap-4"
    >
      <span
        className={cn(
          "w-10 shrink-0 text-center font-extrabold italic leading-none tracking-tighter sm:w-12",
          large ? "text-[44px] sm:text-[52px]" : "text-[38px] sm:text-[44px]",
          rank <= 3 ? "rank-outline-brand" : "rank-outline",
        )}
        aria-label={fmt(t.rank, { n: rank })}
      >
        {rank}
      </span>
      <div className="relative aspect-[9/16] w-14 shrink-0 overflow-hidden rounded-lg bg-surface-2 sm:w-16">
        {drama.poster_url && (
          <Image
            src={drama.poster_url}
            alt=""
            fill
            sizes="72px"
            className="object-cover"
          />
        )}
      </div>
      <div className="min-w-0 flex-1">
        <h3 className="line-clamp-2 text-sm font-semibold leading-snug sm:text-[15px]">
          {drama.title}
        </h3>
        {tags.length > 0 && (
          <p className="mt-1 truncate text-xs text-text-muted">{tags.join(" · ")}</p>
        )}
        <p className="mt-1.5 flex items-center gap-1 text-xs text-text-dim">
          {fmt(t.viewsEp, { views: formatCompact(drama.views), n: drama.total_episodes })}
        </p>
      </div>
    </Link>
  );
}

/** Top-10 ranking in a responsive multi-column layout. */
export function RankingList({ dramas, columns = 2 }: { dramas: Drama[]; columns?: 1 | 2 | 3 }) {
  const cols = { 1: "", 2: "md:grid-cols-2", 3: "md:grid-cols-2 xl:grid-cols-3" }[columns];
  return (
    <ol className={cn("grid gap-x-6 gap-y-1", cols)}>
      {dramas.map((d, i) => (
        <li key={d.id}>
          <RankingItem drama={d} rank={i + 1} />
        </li>
      ))}
    </ol>
  );
}

export function RankingSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="grid gap-x-6 gap-y-3 md:grid-cols-2">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-4 p-2">
          <div className="skeleton h-10 w-10 rounded" />
          <div className="skeleton aspect-[9/16] w-14 rounded-lg sm:w-16" />
          <div className="flex-1 space-y-2">
            <div className="skeleton h-4 w-3/4 rounded" />
            <div className="skeleton h-3 w-1/3 rounded" />
          </div>
        </div>
      ))}
    </div>
  );
}
