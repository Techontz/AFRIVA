import Image from "next/image";
import Link from "next/link";
import { cn, formatCompact } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { Icon } from "../ui/Icon";

export function RankingItem({ drama, rank, large }: { drama: Drama; rank: number; large?: boolean }) {
  const tags = (drama.tags?.length ? drama.tags : drama.categories?.map((c) => c.name) ?? []).slice(0, 2);
  return (
    <Link
      href={`/drama/${drama.slug}`}
      className="group flex items-center gap-3 rounded-xl p-2 transition-colors duration-200 hover:bg-surface sm:gap-4"
    >
      <span
        className={cn(
          "w-10 shrink-0 text-center font-extrabold italic leading-none tracking-tighter sm:w-12",
          large ? "text-[44px] sm:text-[52px]" : "text-[38px] sm:text-[44px]",
          rank <= 3 ? "rank-outline-brand" : "rank-outline",
        )}
        aria-label={`Rank ${rank}`}
      >
        {rank}
      </span>
      <div className="relative aspect-[3/4] w-16 shrink-0 overflow-hidden rounded-md bg-surface-2 sm:w-[72px]">
        {drama.poster_url && (
          <Image
            src={drama.poster_url}
            alt=""
            fill
            sizes="72px"
            className="object-cover transition-transform duration-200 group-hover:scale-[1.05]"
          />
        )}
      </div>
      <div className="min-w-0 flex-1">
        <h3 className="line-clamp-2 text-sm font-bold leading-snug transition-colors group-hover:text-primary sm:text-[15px]">
          {drama.title}
        </h3>
        {tags.length > 0 && (
          <div className="mt-1.5 flex flex-wrap gap-1">
            {tags.map((t) => (
              <span key={t} className="rounded bg-surface-2 px-1.5 py-0.5 text-[10px] font-medium text-text-muted">
                {t}
              </span>
            ))}
          </div>
        )}
        <p className="mt-1.5 flex items-center gap-1 text-xs text-text-dim">
          <Icon name="flame" size={13} className="text-primary" />
          {formatCompact(drama.views)} views · EP {drama.total_episodes}
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
          <div className="skeleton aspect-[3/4] w-16 rounded-md" />
          <div className="flex-1 space-y-2">
            <div className="skeleton h-4 w-3/4 rounded" />
            <div className="skeleton h-3 w-1/3 rounded" />
          </div>
        </div>
      ))}
    </div>
  );
}
