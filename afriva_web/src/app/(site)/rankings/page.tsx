import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Suspense } from "react";
import { RankingItem, RankingSkeleton } from "@/components/site/RankingList";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { asArray } from "@/lib/api";
import { cn, formatCompact } from "@/lib/format";
import { serverGet } from "@/lib/server-api";
import type { Drama } from "@/lib/types";

export const metadata: Metadata = { title: "Rankings", description: "The most-watched Afriva dramas right now." };

const TABS = [
  { key: "trending", label: "Trending", blurb: "What everyone is binging this week" },
  { key: "new", label: "New & Hot", blurb: "Fresh series climbing fast" },
  { key: "popular", label: "All-time Popular", blurb: "The biggest Afriva hits ever" },
] as const;
type TabKey = (typeof TABS)[number]["key"];

export default function RankingsPage({ searchParams }: PageProps<"/rankings">) {
  return (
    <div className="mx-auto max-w-[1100px] px-4 pt-8 sm:px-6 lg:px-8">
      <div className="flex items-center gap-3">
        <span className="grid h-11 w-11 place-items-center rounded-2xl bg-primary">
          <Icon name="trophy" size={22} />
        </span>
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight sm:text-3xl">Rankings</h1>
          <p className="text-sm text-text-muted">Updated daily from real views.</p>
        </div>
      </div>
      <Suspense fallback={<div className="mt-8"><RankingSkeleton rows={10} /></div>}>
        <RankingsContent searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function RankingsContent({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const type: TabKey = TABS.some((t) => t.key === sp.type) ? (sp.type as TabKey) : "trending";
  const data = await serverGet<unknown>("/dramas/rankings", { type });
  const dramas = data === null ? null : asArray<Drama>(data);
  const tab = TABS.find((t) => t.key === type)!;

  return (
    <>
      <div className="scrollbar-none mt-6 flex gap-2 overflow-x-auto" role="tablist">
        {TABS.map((t) => (
          <Link
            key={t.key}
            role="tab"
            aria-selected={t.key === type}
            href={t.key === "trending" ? "/rankings" : `/rankings?type=${t.key}`}
            className={cn(
              "shrink-0 rounded-full px-4 py-2 text-sm font-bold transition-colors",
              t.key === type ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:text-text",
            )}
          >
            {t.label}
          </Link>
        ))}
      </div>
      <p className="mt-3 text-sm text-text-dim">{tab.blurb}</p>

      <div className="mt-6">
        {dramas === null ? (
          <ApiDownState />
        ) : dramas.length === 0 ? (
          <EmptyState icon="trophy" title="No rankings yet" description="Rankings appear once viewers start watching." />
        ) : (
          <>
            <Podium dramas={dramas.slice(0, 3)} />
            <ol className="mt-6 grid gap-1 md:grid-cols-2 md:gap-x-6">
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

function Podium({ dramas }: { dramas: Drama[] }) {
  return (
    <ol className="grid grid-cols-3 gap-3 sm:gap-5">
      {dramas.map((d, i) => (
        <li key={d.id}>
          <Link href={`/drama/${d.slug}`} className="group block">
            <div className="relative aspect-[3/4] overflow-hidden rounded-xl ring-1 ring-black/5 transition-shadow group-hover:ring-primary/60">
              {d.poster_url && (
                <Image src={d.poster_url} alt={d.title} fill sizes="(max-width:640px) 33vw, 300px" className="object-cover transition-transform duration-200 group-hover:scale-[1.03]" />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent" />
              <span className="rank-outline-brand absolute -bottom-2 left-2 text-[56px] font-extrabold italic leading-none tracking-tighter sm:text-[88px]">
                {i + 1}
              </span>
            </div>
            <h3 className="mt-2 line-clamp-2 text-[13px] font-bold leading-snug group-hover:text-primary sm:text-[15px]">{d.title}</h3>
            <p className="mt-0.5 text-xs text-text-dim">{formatCompact(d.views)} views</p>
          </Link>
        </li>
      ))}
    </ol>
  );
}
