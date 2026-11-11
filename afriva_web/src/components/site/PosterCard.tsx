import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { Icon } from "../ui/Icon";
import { BadgeText, CardMeta } from "./SiteLabels";

/** Quiet text label, placed beside the artwork rather than on it so the printed logo and title stay clean. */
export function PosterBadge({ badge, className }: { badge: Drama["badge"]; className?: string }) {
  if (!badge) return null;
  return (
    <span className={cn("font-semibold text-primary", className)}>
      <BadgeText badge={badge} />
    </span>
  );
}

export function dramaGenres(drama: Drama, n = 2): string[] {
  const names = drama.categories?.length ? drama.categories.map((c) => c.name) : drama.tags ?? [];
  return names.slice(0, n);
}

/** Genre label in the reader's language; unknown names (free-text tags) stay as written. */
export function genreName(name: string, categories: Record<string, string>): string {
  return categories[name.toLowerCase()] ?? name;
}

export function GenreChips({ names, className, size = "sm" }: { names: string[]; className?: string; size?: "sm" | "md" }) {
  if (!names.length) return null;
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {names.map((t) => (
        <span
          key={t}
          className={cn(
            "rounded-full bg-text/10 text-text-muted",
            size === "md" ? "px-3 py-1 text-sm" : "px-2.5 py-0.5 text-xs",
          )}
        >
          {t}
        </span>
      ))}
    </div>
  );
}

/** 9:16 artwork so the title printed on the poster stays whole, with a quiet caption underneath. */
export function PosterCard({
  drama,
  className,
  priority,
  sizes = "(max-width: 640px) 38vw, (max-width: 1024px) 24vw, 240px",
}: {
  drama: Drama;
  className?: string;
  priority?: boolean;
  sizes?: string;
}) {
  return (
    <Link href={`/drama/${drama.slug}`} className={cn("group block min-w-0 snap-start", className)}>
      <div className="relative aspect-[9/16] overflow-hidden rounded-[14px] bg-surface shadow-[0_8px_24px_-14px_rgba(0,0,0,0.6)] transition-[transform,box-shadow] duration-300 ease-brand group-hover:-translate-y-1.5 group-hover:shadow-[0_20px_40px_-16px_rgba(0,0,0,0.75)]">
        {drama.poster_url ? (
          <Image
            src={drama.poster_url}
            alt={drama.title}
            fill
            sizes={sizes}
            priority={priority}
            className="object-cover"
          />
        ) : (
          <div className="grid h-full place-items-center text-text-dim">
            <Icon name="film" size={28} />
          </div>
        )}
        <div className="absolute inset-0 grid place-items-center bg-black/20 opacity-0 transition-opacity duration-200 group-hover:opacity-100 group-focus-visible:opacity-100">
          <span className="grid size-12 translate-y-1 place-items-center rounded-full bg-primary text-white shadow-lg transition-transform duration-300 ease-brand group-hover:translate-y-0">
            <Icon name="play" size={20} className="translate-x-px" />
          </span>
        </div>
      </div>
      <h3 className="mt-3 line-clamp-2 text-[13px] font-semibold leading-snug text-text sm:text-sm">{drama.title}</h3>
      <p className="mt-1 truncate text-xs text-text-dim">
        <CardMeta episodes={drama.total_episodes} genre={dramaGenres(drama, 1)[0]} badge={drama.badge} />
      </p>
    </Link>
  );
}

export function PosterCardSkeleton({ className }: { className?: string }) {
  return (
    <div className={className}>
      <div className="skeleton aspect-[9/16] rounded-[14px]" />
      <div className="skeleton mt-3 h-3.5 w-4/5 rounded" />
      <div className="skeleton mt-2 h-3 w-1/2 rounded" />
    </div>
  );
}

/** Width of a card on a horizontal shelf: a peek of the next poster on phones, full columns on desktop. */
export const shelfItemClass =
  "w-[calc((100%-2*12px)/2.6)] shrink-0 sm:w-[calc((100%-3*14px)/4.3)] lg:w-[calc((100%-5*18px)/6)] xl:w-[calc((100%-6*18px)/7)] min-[1800px]:w-[calc((100%-7*18px)/8)]";

/** 3 columns on phones, up to 7 on wide screens. */
export const gridClass = "grid grid-cols-3 gap-x-3 gap-y-7 sm:grid-cols-4 sm:gap-x-4 md:grid-cols-5 lg:grid-cols-6 lg:gap-x-[18px] lg:gap-y-9 xl:grid-cols-7";
