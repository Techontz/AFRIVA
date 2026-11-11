import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Suspense } from "react";
import { RankingItem, RankingSkeleton } from "@/components/site/RankingList";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { asArray } from "@/lib/api";
import { cn, formatCompact } from "@/lib/format";
import { fmt } from "@/i18n/format";
import { getDict } from "@/i18n/server";
import { serverGet } from "@/lib/server-api";
import type { Drama } from "@/lib/types";

export async function generateMetadata(): Promise<Metadata> {
  const t = (await getDict()).site.rankings;
  return { title: t.title, description: t.metaDescription };
}

const TABS = ["trending", "new", "popular"] as const;
type TabKey = (typeof TABS)[number];

export default async function RankingsPage({ searchParams }: PageProps<"/[lang]/rankings">) {
  const t = (await getDict()).site.rankings;
  return (
    <div className="mx-auto max-w-[1100px] px-4 pt-6 sm:px-6 lg:px-8 lg:pt-10">
      <h1 className="text-3xl font-extrabold tracking-tight lg:text-[42px] lg:leading-tight">{t.title}</h1>
      <p className="mt-1.5 text-[15px] text-text-muted">{t.subtitle}</p>
      <Suspense fallback={<div className="mt-8"><RankingSkeleton rows={10} /></div>}>
        <RankingsContent searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function RankingsContent({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const type: TabKey = TABS.includes(sp.type as TabKey) ? (sp.type as TabKey) : "trending";
  const [data, dict] = await Promise.all([serverGet<unknown>("/dramas/rankings", { type }), getDict()]);
  const dramas = data === null ? null : asArray<Drama>(data);
  const t = dict.site.rankings;

  return (
    <>
      <div className="scrollbar-none mt-6 flex gap-2 overflow-x-auto" role="tablist">
        {TABS.map((key) => (
          <Link
            key={key}
            role="tab"
            aria-selected={key === type}
            href={key === "trending" ? "/rankings" : `/rankings?type=${key}`}
            className={cn(
              "shrink-0 rounded-full px-4 py-1.5 text-[13px] font-semibold transition-colors",
              key === type ? "bg-text text-bg" : "bg-text/10 text-text-muted hover:text-text",
            )}
          >
            {t.tabs[key].label}
          </Link>
        ))}
      </div>
      <p className="mt-3 text-sm text-text-dim">{t.tabs[type].blurb}</p>

      <div className="mt-6">
        {dramas === null ? (
          <ApiDownState />
        ) : dramas.length === 0 ? (
          <EmptyState icon="trophy" title={t.emptyTitle} description={t.emptyBody} />
        ) : (
          <>
            <Podium dramas={dramas.slice(0, 3)} viewsLabel={dict.site.card.views} playLabel={dict.site.hero.play} />
            <ol className="mt-8 grid gap-1 md:grid-cols-2 md:gap-x-6">
              {dramas.slice(3).map((d, i) => (
                <li key={d.id}>
                  <RankingItem drama={d} rank={i + 4} />
                </li>
              ))}
            </ol>
          </>
        )}
      </div>
    </>
  );
}

const MEDALS = [
  { badge: "bg-gradient-to-br from-[#FFE08A] to-[#C9971C] text-black" },
  { badge: "bg-gradient-to-br from-[#F1F4F7] to-[#8D99A6] text-black" },
  { badge: "bg-gradient-to-br from-[#F3B37A] to-[#9A5422] text-black" },
];

/**
 * Top 3 as a podium: full 9:16 posters (never cropped, so the printed title stays clean), #1 in the
 * middle and raised, with a medal badge under each poster instead of a numeral over the artwork.
 */
function Podium({ dramas, viewsLabel, playLabel }: { dramas: Drama[]; viewsLabel: string; playLabel: string }) {
  const order = dramas.length === 3 ? [1, 0, 2] : dramas.map((_, i) => i);
  return (
    <section className="pb-2 pt-6 sm:pt-8">
      <ol className="grid grid-cols-3 items-end gap-3 sm:gap-8">
        {order.map((i) => {
          const d = dramas[i];
          const m = MEDALS[i];
          const first = i === 0;
          return (
            <li key={d.id} className={cn("flex flex-col items-center text-center", first ? "sm:-mt-6" : "sm:mt-8")}>
              <Link href={`/drama/${d.slug}`} className="group block w-full">
                <div
                  className={cn(
                    "relative mx-auto aspect-[9/16] overflow-hidden rounded-[14px] shadow-[0_24px_50px_-20px_rgba(0,0,0,0.75)] transition-transform duration-300 ease-brand group-hover:-translate-y-1",
                    first ? "w-full max-w-[250px]" : "w-[88%] max-w-[210px]",
                  )}
                >
                  {d.poster_url && (
                    <Image src={d.poster_url} alt={d.title} fill sizes="(max-width:640px) 33vw, 250px" priority={first} loading="eager" className="object-cover" />
                  )}
                </div>
                <span
                  className={cn(
                    "relative z-10 mx-auto mt-3 grid place-items-center rounded-full font-extrabold",
                    m.badge,
                    first ? "size-9 text-base sm:size-10 sm:text-lg" : "size-8 text-sm sm:size-9 sm:text-base",
                  )}
                >
                  {i + 1}
                </span>
                <h3 className="mt-2 line-clamp-2 break-words text-[13px] font-semibold leading-snug sm:text-base">{d.title}</h3>
              </Link>
              <p className="mt-1 flex items-center justify-center gap-1 text-xs text-text-dim">
                {fmt(viewsLabel, { n: formatCompact(d.views) })}
              </p>
              <Link
                href={`/drama/${d.slug}/ep/1`}
                className="mt-3 hidden items-center gap-1.5 rounded-full bg-text/10 px-4 py-2 text-xs font-semibold text-text transition hover:bg-text/15 sm:inline-flex"
              >
                <Icon name="play" size={13} className="fill-current" />
                {playLabel}
              </Link>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
