import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { PageNav } from "@/components/site/PageNav";
import { PosterCard, PosterCardSkeleton, genreName, gridClass } from "@/components/site/PosterCard";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import { getDict } from "@/i18n/server";
import { cn } from "@/lib/format";
import { serverGet, serverPage } from "@/lib/server-api";
import type { Category, Drama } from "@/lib/types";

export async function generateMetadata(): Promise<Metadata> {
  const t = (await getDict()).site.browse;
  return { title: t.title, description: t.metaDescription };
}

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

export default async function BrowsePage({ searchParams }: PageProps<"/[lang]/browse">) {
  const t = (await getDict()).site.browse;
  return (
    <div className="site-container pt-6 lg:pt-10">
      <h1 className="text-3xl font-extrabold tracking-tight lg:text-[42px] lg:leading-tight">{t.title}</h1>
      <p className="mt-1.5 text-[15px] text-text-muted">{t.subtitle}</p>
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

  const [categories, result, dict] = await Promise.all([
    serverGet<Category[]>("/categories", undefined, 300),
    serverPage<Drama>("/dramas", { category: sp.category, sort: sp.sort, page, per_page: 28 }),
    getDict(),
  ]);
  const t = dict.site.browse;

  const chips = [{ id: 0, name: t.all, slug: "all" }, ...(categories ?? [])];
  const activeCat = sp.category ?? "all";

  return (
    <>
      <div className="sticky top-(--header-h) z-30 -mx-4 mt-5 bg-bg/72 px-4 py-2.5 backdrop-blur-2xl backdrop-saturate-150 sm:-mx-6 sm:px-6 lg:mx-0 lg:px-0">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
          <div className="scrollbar-none -my-1 flex min-w-0 flex-1 gap-2 overflow-x-auto py-1" role="list" aria-label={t.categories}>
            {chips.map((c) => (
              <Link
                key={c.slug}
                role="listitem"
                href={hrefFor(sp, { category: c.slug, page: "1" })}
                aria-current={activeCat === c.slug ? "true" : undefined}
                className={cn(
                  "shrink-0 rounded-full px-4 py-1.5 text-[13px] font-semibold transition-colors duration-150",
                  activeCat === c.slug ? "bg-text text-bg" : "bg-text/10 text-text-muted hover:bg-text/15 hover:text-text",
                )}
              >
                {genreName(c.name, dict.site.card.categories)}
              </Link>
            ))}
          </div>
          <div className="flex shrink-0 self-start rounded-full bg-text/10 p-0.5 sm:self-auto" role="group" aria-label={t.sort}>
            {(["popular", "newest"] as const).map((s) => (
              <Link
                key={s}
                href={hrefFor(sp, { sort: s, page: "1" })}
                aria-current={sp.sort === s ? "true" : undefined}
                className={cn(
                  "rounded-full px-3 py-1 text-xs font-semibold transition-colors",
                  sp.sort === s ? "bg-bg text-text" : "text-text-muted hover:text-text",
                )}
              >
                {t[s]}
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
            title={t.emptyTitle}
            description={t.emptyBody}
            action={
              <Link href="/browse" className="text-sm font-semibold text-primary hover:underline">
                {t.showAll}
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
      <div className="mt-5 flex gap-2 overflow-hidden py-2.5">
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
