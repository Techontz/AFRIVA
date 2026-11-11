import type { Metadata } from "next";
import { Suspense } from "react";
import { DramaSection } from "@/components/site/DramaRow";
import { PageNav } from "@/components/site/PageNav";
import { PosterCard, PosterCardSkeleton, gridClass } from "@/components/site/PosterCard";
import { SearchForm } from "@/components/site/SearchForm";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import { fmt, plural } from "@/i18n/format";
import { getDict } from "@/i18n/server";
import { asArray } from "@/lib/api";
import { serverGet, serverPage } from "@/lib/server-api";
import type { Drama } from "@/lib/types";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getDict()).site.search.title };
}

export default function SearchPage({ searchParams }: PageProps<"/[lang]/search">) {
  return (
    <div className="site-container pt-6 lg:pt-10">
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
  const [result, dict] = await Promise.all([
    q ? serverPage<Drama>("/dramas", { q, page, per_page: 28 }, 30) : null,
    getDict(),
  ]);
  // With nothing typed yet, offer something to watch instead of an empty page.
  const trending = q ? [] : asArray<Drama>((await serverGet<unknown>("/dramas/rankings", { type: "trending" })) ?? []);
  const t = dict.site.search;

  return (
    <>
      <div className="mx-auto max-w-2xl">
        <SearchForm key={q} initial={q} />
      </div>
      <div className="mt-8">
        {!q ? (
          trending.length ? (
            <div className="mt-2">
              <DramaSection title={dict.site.home.sections.trending ?? t.title} href="/rankings" dramas={trending} />
            </div>
          ) : (
            <EmptyState icon="search" title={t.promptTitle} description={t.promptBody} />
          )
        ) : !result ? (
          <ApiDownState />
        ) : result.items.length === 0 ? (
          <EmptyState icon="search" title={fmt(t.noResults, { q })} description={t.noResultsBody} />
        ) : (
          <>
            <p className="mb-5 text-sm text-text-muted">
              {plural(result.meta.total, t.results)}{" "}
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
