import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { DramaButtons, DramaEpisodes, DramaPersonalProvider } from "@/components/site/DramaActions";
import { DramaSection } from "@/components/site/DramaRow";
import { PosterBadge, genreName } from "@/components/site/PosterCard";
import { ApiDownState } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { fmt, plural } from "@/i18n/format";
import { getDict } from "@/i18n/server";
import { formatCompact } from "@/lib/format";
import { serverGetWithStatus } from "@/lib/server-api";
import type { DramaDetail } from "@/lib/types";

async function loadDrama(slug: string) {
  return serverGetWithStatus<DramaDetail>(`/dramas/${encodeURIComponent(slug)}`);
}

export async function generateMetadata({ params }: PageProps<"/[lang]/drama/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  const [{ data }, t] = await Promise.all([loadDrama(slug), getDict()]);
  if (!data) return { title: t.site.meta.drama };
  return {
    title: data.title,
    description: data.synopsis?.slice(0, 160),
    openGraph: { title: data.title, description: data.synopsis?.slice(0, 160), images: data.backdrop_url ? [data.backdrop_url] : [] },
  };
}

export default function DramaPage({ params }: PageProps<"/[lang]/drama/[slug]">) {
  return (
    <Suspense fallback={<DramaSkeleton />}>
      <DramaContent params={params} />
    </Suspense>
  );
}

async function DramaContent({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const [{ data: drama, status }, dict] = await Promise.all([loadDrama(slug), getDict()]);
  const t = dict.site;
  if (status === 404) notFound();
  if (!drama) {
    return (
      <div className="site-container pt-12">
        <ApiDownState />
      </div>
    );
  }
  const genres = (drama.categories ?? []).map((c) => genreName(c.name, t.card.categories));
  const rawGenres = (drama.categories ?? []).map((c) => c.name);
  const tags = (drama.tags ?? []).filter((tag) => !rawGenres.includes(tag));

  return (
    <DramaPersonalProvider drama={drama}>
      <section className="relative -mt-(--header-h)">
        {/* Soft colour wash taken from the artwork. */}
        <div className="absolute inset-0 overflow-hidden" aria-hidden>
          {drama.poster_url && (
            <Image src={drama.poster_url} alt="" fill sizes="100vw" className="scale-125 object-cover opacity-70 blur-3xl saturate-150 [:root[data-theme=light]_&]:opacity-40" />
          )}
          <div className="absolute inset-0 bg-gradient-to-b from-bg/30 via-bg/70 to-bg" />
        </div>

        <div className="site-container relative pb-10 pt-[calc(var(--header-h)+1.25rem)] lg:pb-14 lg:pt-[calc(var(--header-h)+2rem)]">
          <nav className="mb-6 hidden items-center gap-1 text-xs text-text-muted sm:flex" aria-label={t.drama.breadcrumb}>
            <Link href="/" className="hover:text-text">{dict.common.nav.home}</Link>
            <Icon name="chevron-right" size={14} />
            <Link href="/browse" className="hover:text-text">{dict.common.nav.browse}</Link>
            <Icon name="chevron-right" size={14} />
            <span className="truncate text-text">{drama.title}</span>
          </nav>

          <div className="flex flex-col items-center gap-6 sm:flex-row sm:items-end sm:gap-8 lg:gap-12">
            <div className="relative aspect-[9/16] w-[148px] shrink-0 overflow-hidden rounded-[18px] bg-surface shadow-[0_30px_70px_-24px_rgba(0,0,0,0.8)] sm:w-52 lg:w-[272px]">
              {drama.poster_url && <Image src={drama.poster_url} alt={drama.title} fill priority sizes="272px" className="object-cover" />}
            </div>

            <div className="flex min-w-0 flex-1 flex-col items-center text-center sm:items-start sm:text-left">
              <h1 className="text-[28px] font-extrabold leading-[1.08] tracking-tight sm:text-4xl lg:text-[52px]">{drama.title}</h1>
              <p className="mt-3 flex flex-wrap items-center justify-center gap-x-2.5 gap-y-1 text-sm text-text-muted sm:justify-start">
                {drama.badge && (
                  <>
                    <PosterBadge badge={drama.badge} />
                    <span aria-hidden>·</span>
                  </>
                )}
                <span>{plural(drama.total_episodes, t.card.episodes)}</span>
                <span aria-hidden>·</span>
                <span>{fmt(t.card.views, { n: formatCompact(drama.views) })}</span>
              </p>
              {genres.length > 0 && <p className="mt-1 text-sm text-text-muted">{genres.join(" · ")}</p>}
              <p className="mt-3 line-clamp-3 max-w-2xl sm:mt-4 sm:line-clamp-5 text-[15px] leading-relaxed text-text-muted lg:text-base">{drama.synopsis}</p>
              {(drama.company || tags.length > 0) && (
                <p className="mt-3 hidden max-w-2xl text-[13px] text-text-dim sm:block">
                  {[drama.company?.name, ...tags].filter(Boolean).join(" · ")}
                </p>
              )}
              <DramaButtons />
            </div>
          </div>
        </div>
      </section>

      <div className="site-container">
        <DramaEpisodes />

        {drama.related?.length > 0 && (
          <div className="mt-14">
            <DramaSection title={t.drama.related} icon="sparkles" dramas={drama.related} />
          </div>
        )}
      </div>
    </DramaPersonalProvider>
  );
}

function DramaSkeleton() {
  return (
    <div className="site-container pt-8">
      <div className="flex flex-col items-center gap-6 sm:flex-row sm:items-end sm:gap-8 lg:gap-12">
        <div className="skeleton aspect-[9/16] w-[148px] shrink-0 rounded-[18px] sm:w-52 lg:w-[272px]" />
        <div className="w-full flex-1 space-y-4">
          <div className="skeleton h-10 w-2/3 rounded-lg" />
          <div className="skeleton h-4 w-1/3 rounded" />
          <div className="skeleton h-4 w-full max-w-2xl rounded" />
          <div className="skeleton h-4 w-5/6 max-w-xl rounded" />
          <div className="flex gap-3 pt-4">
            <div className="skeleton h-12 w-36 rounded-full" />
            <div className="skeleton h-12 w-40 rounded-full" />
          </div>
        </div>
      </div>
      <div className="mt-12 grid grid-cols-[repeat(auto-fill,minmax(56px,1fr))] gap-2">
        {Array.from({ length: 24 }).map((_, i) => (
          <div key={i} className="skeleton h-14 rounded-xl" />
        ))}
      </div>
    </div>
  );
}
