import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { Icon } from "../ui/Icon";

const badgeStyles = {
  hot: "bg-primary text-white",
  new: "bg-white text-black",
  vip: "bg-black/80 text-white ring-1 ring-white/30",
} as const;

export function PosterBadge({ badge }: { badge: Drama["badge"] }) {
  if (!badge) return null;
  return (
    <span
      className={cn(
        "absolute left-0 top-0 z-10 rounded-br-md rounded-tl-[6px] px-1.5 py-0.5 text-[10px] font-extrabold uppercase tracking-wide",
        badgeStyles[badge],
      )}
    >
      {badge === "vip" ? "VIP" : badge === "hot" ? "Hot" : "New"}
    </span>
  );
}

export function dramaGenres(drama: Drama, n = 2): string[] {
  const names = drama.categories?.length ? drama.categories.map((c) => c.name) : drama.tags ?? [];
  return names.slice(0, n);
}

export function GenreChips({ names, className, size = "sm" }: { names: string[]; className?: string; size?: "sm" | "md" }) {
  if (!names.length) return null;
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {names.map((t) => (
        <span
          key={t}
          className={cn(
            "rounded-full bg-surface-2 text-text-muted",
            size === "md" ? "px-3 py-1 text-sm" : "px-2.5 py-0.5 text-xs",
          )}
        >
          {t}
        </span>
      ))}
    </div>
  );
}

/** Uniform 3:4 card: poster → title (2 lines) → "60 Episodes" → 1 genre chip. */
export function PosterCard({
  drama,
  className,
  priority,
  sizes = "(max-width: 640px) 33vw, (max-width: 1024px) 25vw, 260px",
}: {
  drama: Drama;
  className?: string;
  priority?: boolean;
  sizes?: string;
}) {
  return (
    <Link href={`/drama/${drama.slug}`} className={cn("group block min-w-0 outline-none", className)}>
      <div className="relative aspect-[3/4] overflow-hidden rounded-[6px] bg-surface group-focus-visible:ring-2 group-focus-visible:ring-primary">
        <PosterBadge badge={drama.badge} />
        {drama.poster_url ? (
          <Image
            src={drama.poster_url}
            alt={drama.title}
            fill
            sizes={sizes}
            priority={priority}
            className="object-cover transition-transform duration-200 ease-out group-hover:scale-[1.03]"
          />
        ) : (
          <div className="grid h-full place-items-center text-text-dim">
            <Icon name="film" size={28} />
          </div>
        )}
        <div className="absolute inset-0 grid place-items-center bg-black/25 opacity-0 transition-opacity duration-200 group-hover:opacity-100">
          <span className="grid h-11 w-11 place-items-center rounded-full bg-primary text-white">
            <Icon name="play" size={18} className="translate-x-px" />
          </span>
        </div>
      </div>
      <h3 className="mt-2.5 line-clamp-2 text-sm font-medium leading-snug text-text transition-colors group-hover:text-primary sm:text-[17px]">
        {drama.title}
      </h3>
      <p className="mt-1 text-xs text-text-dim sm:text-[13px]">{drama.total_episodes} Episodes</p>
      <GenreChips names={dramaGenres(drama, 1)} className="mt-2" />
    </Link>
  );
}

export function PosterCardSkeleton() {
  return (
    <div>
      <div className="skeleton aspect-[3/4] rounded-[6px]" />
      <div className="skeleton mt-2.5 h-4 w-4/5 rounded" />
      <div className="skeleton mt-1.5 h-3 w-16 rounded" />
      <div className="skeleton mt-2 h-5 w-14 rounded-full" />
    </div>
  );
}

/** 3 cols mobile · 4 tablet · 6 desktop. */
export const gridClass = "grid grid-cols-3 gap-x-3 gap-y-7 sm:grid-cols-4 sm:gap-x-[18px] lg:grid-cols-6";
