import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { PageNav } from "@/components/site/PageNav";
import { PosterCard, PosterCardSkeleton, gridClass } from "@/components/site/PosterCard";
import { SearchForm } from "@/components/site/SearchForm";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import { serverPage } from "@/lib/server-api";
import type { Drama } from "@/lib/types";

export const metadata: Metadata = { title: "Search" };

export default function SearchPage({ searchParams }: PageProps<"/search">) {
  return (
    <div className="site-container pt-8">
      <Suspense fallback={<SearchSkeleton />}>
        <SearchContent searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function SearchContent({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const q = typeof sp.q === "string" ? sp.q.trim() : "";
  const page = Math.max(1, Number(sp.page) || 1);
  const result = q ? await serverPage<Drama>("/dramas", { q, page, per_page: 28 }, 30) : null;

  return (
    <>
      <div className="mx-auto max-w-2xl">
        <SearchForm key={q} initial={q} />
      </div>
      <div className="mt-8">
        {!q ? (
          <EmptyState
            icon="search"
            title="What do you feel like watching?"
            description="Search by title. Or jump into the charts."
            action={
              <Link href="/rankings" className="text-sm font-semibold text-primary hover:underline">
                See what’s trending →
              </Link>
            }
          />
        ) : !result ? (
          <ApiDownState />
        ) : result.items.length === 0 ? (
          <EmptyState icon="search" title={`No results for “${q}”`} description="Check the spelling or try a shorter keyword." />
        ) : (
          <>
            <p className="mb-5 text-sm text-text-muted">
              {result.meta.total.toLocaleString()} result{result.meta.total === 1 ? "" : "s"} for{" "}
              <span className="font-semibold text-text">“{q}”</span>
            </p>
            <div className={gridClass}>
              {result.items.map((d) => (
                <PosterCard key={d.id} drama={d} />
              ))}
            </div>
            <PageNav
              page={result.meta.current_page}
              last={result.meta.last_page}
              hrefFor={(p) => `/search?q=${encodeURIComponent(q)}${p > 1 ? `&page=${p}` : ""}`}
            />
          </>
        )}
      </div>
    </>
  );
}

function SearchSkeleton() {
  return (
    <>
      <div className="skeleton mx-auto h-14 max-w-2xl rounded-full" />
      <div className={`${gridClass} mt-12`}>
        {Array.from({ length: 7 }).map((_, i) => (
          <PosterCardSkeleton key={i} />
        ))}
      </div>
    </>
  );
}
