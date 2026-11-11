import Link from "next/link";
import { Suspense } from "react";
import { DramaSection } from "@/components/site/DramaRow";
import { FeaturedList } from "@/components/site/FeaturedList";
import { HeroCinematic } from "@/components/site/hero/HeroCinematic";
import { PosterCardSkeleton, shelfItemClass } from "@/components/site/PosterCard";
import { BLEED, HERO_HEIGHT } from "@/components/site/hero/layout";
import { buttonClass } from "@/components/ui/Button";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import type { IconName } from "@/components/ui/Icon";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { getDict } from "@/i18n/server";
import { serverGet } from "@/lib/server-api";
import type { Drama, HomeData, HomeSection } from "@/lib/types";

/** Display order + icons/links for the API's section keys; unknown keys follow in API order. */
const SECTION_META: Record<string, { icon: IconName; href: string }> = {
  must_watch: { icon: "star", href: "/browse?sort=popular" },
  trending: { icon: "flame", href: "/rankings" },
  hidden_gems: { icon: "sparkles", href: "/browse?sort=popular" },
  new_releases: { icon: "clock", href: "/browse?sort=newest" },
  popular: { icon: "trophy", href: "/rankings?type=popular" },
};
const ORDER = ["must_watch", "trending", "hidden_gems"];

function metaFor(s: HomeSection, titles: Dictionary["site"]["home"]["sections"]) {
  const known = SECTION_META[s.key];
  if (known) return { ...known, title: titles[s.key] ?? s.title };
  return {
    title: s.title,
    icon: "tag" as IconName,
    href: `/browse?category=${encodeURIComponent(s.category ?? s.key.replace(/_/g, "-"))}`,
  };
}

function orderSections(sections: HomeSection[]) {
  const rank = (k: string) => {
    const i = ORDER.indexOf(k);
    return i === -1 ? ORDER.length : i;
  };
  return sections
    .map((s, i) => ({ s, i }))
    .sort((a, b) => rank(a.s.key) - rank(b.s.key) || a.i - b.i)
    .map(({ s }) => s);
}

/** Featured = home banners in sets of 3 (topped up from sections only if fewer than 3). */
function featuredFrom(home: HomeData): Drama[] {
  const target = Math.max(3, Math.floor((home.banners?.length ?? 0) / 3) * 3);
  const seen = new Set<number>();
  const out: Drama[] = [];
  const pool = [...(home.banners ?? []), ...(home.sections ?? []).flatMap((s) => s.dramas ?? [])];
  for (const d of pool) {
    if (out.length >= target) break;
    if (seen.has(d.id)) continue;
    seen.add(d.id);
    out.push(d);
  }
  return out;
}

export default function HomePage() {
  return (
    <div className="site-container">
      <Suspense fallback={<HomeSkeleton />}>
        <HomeContent />
      </Suspense>
    </div>
  );
}

async function HomeContent() {
  const [home, t] = await Promise.all([serverGet<HomeData>("/home"), getDict()]);
  if (!home) {
    return (
      <div className="pt-6">
        <ApiDownState action={<Link href="/" className={buttonClass("secondary")}>{t.common.feedback.tryAgain}</Link>} />
      </div>
    );
  }
  const sections = orderSections(home.sections?.filter((s) => s.dramas?.length) ?? []);
  const featured = featuredFrom(home);

  if (!sections.length && !featured.length) {
    return <EmptyState title={t.site.home.emptyTitle} description={t.site.home.emptyBody} />;
  }

  return (
    <div className="space-y-10 lg:space-y-14">
      {home.banners?.length ? <HeroCinematic dramas={home.banners} labels={t.site.hero} /> : <FeaturedList dramas={featured} />}
      {sections.map((s) => {
        const m = metaFor(s, t.site.home.sections);
        return <DramaSection key={s.key} title={m.title} icon={m.icon} href={m.href} dramas={s.dramas} />;
      })}
    </div>
  );
}

function HomeSkeleton() {
  return (
    <div className="space-y-10 lg:space-y-14">
      <div className={`${BLEED} ${HERO_HEIGHT} skeleton`} />
      <div>
        <div className="skeleton mb-5 h-7 w-44 rounded-lg" />
        <div className="flex gap-3 overflow-hidden lg:gap-[18px]">
          {Array.from({ length: 7 }).map((_, i) => (
            <PosterCardSkeleton key={i} className={shelfItemClass} />
          ))}
        </div>
      </div>
    </div>
  );
}
