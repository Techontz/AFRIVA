import Link from "next/link";
import { cn } from "@/lib/format";
import { T } from "@/lib/i18n";
import { Icon } from "../ui/Icon";

/** Server-friendly pagination built from links. */
export function PageNav({
  page,
  last,
  hrefFor,
}: {
  page: number;
  last: number;
  hrefFor: (p: number) => string;
}) {
  if (last <= 1) return null;
  const pages: (number | "…")[] = [];
  for (let p = 1; p <= last; p++) {
    if (p === 1 || p === last || Math.abs(p - page) <= 1) pages.push(p);
    else if (pages[pages.length - 1] !== "…") pages.push("…");
  }
  const base =
    "grid h-10 min-w-10 place-items-center rounded-full px-3 text-sm font-semibold transition-colors duration-150";
  return (
    <nav className="mt-10 flex items-center justify-center gap-1.5" aria-label="Kurasa">
      {page > 1 ? (
        <Link href={hrefFor(page - 1)} className={cn(base, "bg-surface-2 hover:bg-surface-3")}>
          <Icon name="chevron-left" size={18} />
          <span className="sr-only">
            <T>Previous page</T>
          </span>
        </Link>
      ) : null}
      {pages.map((p, i) =>
        p === "…" ? (
          <span key={`e${i}`} className="px-1 text-text-dim">
            …
          </span>
        ) : (
          <Link
            key={p}
            href={hrefFor(p)}
            aria-current={p === page ? "page" : undefined}
            className={cn(base, p === page ? "bg-primary text-white" : "text-text-muted hover:bg-surface-2 hover:text-text")}
          >
            {p}
          </Link>
        ),
      )}
      {page < last ? (
        <Link href={hrefFor(page + 1)} className={cn(base, "bg-surface-2 hover:bg-surface-3")}>
          <Icon name="chevron-right" size={18} />
          <span className="sr-only">
            <T>Next page</T>
          </span>
        </Link>
      ) : null}
    </nav>
  );
}
