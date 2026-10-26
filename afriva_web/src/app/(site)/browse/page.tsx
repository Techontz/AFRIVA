import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { PageNav } from "@/components/site/PageNav";
import { PosterCard, PosterCardSkeleton, gridClass } from "@/components/site/PosterCard";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import { cn } from "@/lib/format";
import { T } from "@/lib/i18n";
import { serverGet, serverPage } from "@/lib/server-api";
import type { Category, Drama } from "@/lib/types";

export const metadata: Metadata = {
  title: "Vinjari",
  description: "Vinjari series fupi za Kiafrika kwa kategoria: Mapenzi, Historia, Siri na Mafumbo, Vita na Mashujaa, Vichekesho, Upelelezi, Maisha na Hadithi za Afrika.",
};

type SP = { category?: string; sort?: string; page?: string };

function hrefFor(sp: SP, patch: Partial<SP>) {
  const next = { ...sp, ...patch };
  const params = new URLSearchParams();
  if (next.category && next.category !== "all") params.set("category", next.category);
  if (next.sort && next.sort !== "popular") params.set("sort", next.sort);
  if (next.page && next.page !== "1") params.set("page", next.page);
  const s = params.toString();
  return `/browse${s ? `?${s}` : ""}`;
}

export default function BrowsePage({ searchParams }: PageProps<"/browse">) {
  return (
    <div className="site-container pt-8">
      <h1 className="text-2xl font-extrabold tracking-tight sm:text-3xl">
        <T>Browse</T>
      </h1>
      <p className="mt-1 text-sm text-text-muted">
        <T>Find your next obsession, one episode at a time.</T>
      </p>
      <Suspense fallback={<BrowseSkeleton />}>
        <BrowseContent searchParams={searchParams as Promise<SP>} />
      </Suspense>
    </div>
  );
}

async function BrowseContent({ searchParams }: { searchParams: Promise<SP> }) {
  const raw = await searchParams;
  const sp: SP = {
    category: typeof raw.category === "string" ? raw.category : undefined,
    sort: raw.sort === "newest" ? "newest" : "popular",
    page: typeof raw.page === "string" ? raw.page : "1",
  };
  const page = Math.max(1, Number(sp.page) || 1);

  const [categories, result] = await Promise.all([
    serverGet<Category[]>("/categories", undefined, 300),
    serverPage<Drama>("/dramas", { category: sp.category, sort: sp.sort, page, per_page: 28 }),
  ]);

  const chips = [{ id: 0, name: "All", slug: "all" }, ...(categories ?? [])];
  const activeCat = sp.category ?? "all";

  return (
    <>
      <div className="sticky top-16 lg:top-[88px] z-30 mt-6 border-b border-border bg-bg/90 py-3 backdrop-blur-xl">
        <div className="flex items-center gap-3">
          <div className="scrollbar-none -my-1 flex flex-1 gap-2 overflow-x-auto py-1" role="list" aria-label="Kategoria">
            {chips.map((c) => (
              <Link
                key={c.slug}
                role="listitem"
                href={hrefFor(sp, { category: c.slug, page: "1" })}
                aria-current={activeCat === c.slug ? "true" : undefined}
                className={cn(
                  "shrink-0 rounded-full px-4 py-1.5 text-[13px] font-semibold transition-colors duration-150",
                  activeCat === c.slug ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:bg-surface-3 hover:text-text",
                )}
              >
                {c.id === 0 ? <T>{c.name}</T> : c.name}
              </Link>
            ))}
          </div>
          <div className="flex shrink-0 rounded-full bg-surface-2 p-1" role="group" aria-label="Panga">
            {(["popular", "newest"] as const).map((s) => (
              <Link
                key={s}
                href={hrefFor(sp, { sort: s, page: "1" })}
                aria-current={sp.sort === s ? "true" : undefined}
                className={cn(
                  "rounded-full px-3 py-1 text-xs font-bold capitalize transition-colors",
                  sp.sort === s ? "bg-surface text-text shadow" : "text-text-dim hover:text-text",
                )}
              >
                <T>{s === "popular" ? "Popular" : "Newest"}</T>
              </Link>
            ))}
          </div>
        </div>
      </div>

      <div className="mt-6">
        {!result ? (
          <ApiDownState />
        ) : result.items.length === 0 ? (
          <EmptyState
            title="No dramas here yet"
            description={<T>Try another category. New series land every week.</T>}
            action={
              <Link href="/browse" className="text-sm font-semibold text-primary hover:underline">
                <T>Show all dramas</T>
              </Link>
            }
          />
        ) : (
          <>
            <div className={gridClass}>
              {result.items.map((d, i) => (
                <PosterCard key={d.id} drama={d} priority={i < 6} />
              ))}
            </div>
            <PageNav
              page={result.meta.current_page}
              last={result.meta.last_page}
              hrefFor={(p) => hrefFor(sp, { page: String(p) })}
            />
          </>
        )}
      </div>
    </>
  );
}

function BrowseSkeleton() {
  return (
    <>
      <div className="mt-6 flex gap-2 py-3">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="skeleton h-8 w-20 shrink-0 rounded-full" />
        ))}
      </div>
      <div className={cn(gridClass, "mt-6")}>
        {Array.from({ length: 14 }).map((_, i) => (
          <PosterCardSkeleton key={i} />
        ))}
      </div>
    </>
  );
}
