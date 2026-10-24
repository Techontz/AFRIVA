import Link from "next/link";
import { Suspense } from "react";
import { DramaSection } from "@/components/site/DramaRow";
import { FeaturedList } from "@/components/site/FeaturedList";
import { PosterCardSkeleton, gridClass } from "@/components/site/PosterCard";
import { buttonClass } from "@/components/ui/Button";
import { ApiDownState, EmptyState } from "@/components/ui/Feedback";
import type { IconName } from "@/components/ui/Icon";
import { serverGet } from "@/lib/server-api";
import type { Drama, HomeData, HomeSection } from "@/lib/types";

/** Display order + labels for the API's section keys; unknown keys follow in API order. */
const SECTION_META: Record<string, { title: string; icon: IconName; href: string }> = {
  must_watch: { title: "Must-sees", icon: "star", href: "/browse?sort=popular" },
  trending: { title: "Trending", icon: "flame", href: "/rankings" },
  hidden_gems: { title: "Hidden Gems", icon: "sparkles", href: "/browse?sort=popular" },
  new_releases: { title: "New Releases", icon: "clock", href: "/browse?sort=newest" },
  popular: { title: "Popular", icon: "trophy", href: "/rankings?type=popular" },
};
const ORDER = ["must_watch", "trending", "hidden_gems"];

function metaFor(s: HomeSection) {
  return (
    SECTION_META[s.key] ?? {
      title: s.title,
      icon: "tag" as IconName,
      href: `/browse?category=${encodeURIComponent(s.key.replace(/_/g, "-"))}`,
    }
  );
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
    <div className="site-container pt-6">
      <Suspense fallback={<HomeSkeleton />}>
        <HomeContent />
      </Suspense>
    </div>
  );
}

async function HomeContent() {
  const home = await serverGet<HomeData>("/home");
  if (!home) {
    return (
      <div className="pt-6">
        <ApiDownState action={<Link href="/" className={buttonClass("secondary")}>Try again</Link>} />
      </div>
    );
  }
  const sections = orderSections(home.sections?.filter((s) => s.dramas?.length) ?? []);
  const featured = featuredFrom(home);

  if (!sections.length && !featured.length) {
    return <EmptyState title="New dramas are on the way" description="Our studios are cutting the next big series. Check back soon." />;
  }

  return (
    <div className="space-y-12 lg:space-y-14">
      <FeaturedList dramas={featured} />
      {sections.map((s) => {
        const m = metaFor(s);
        return <DramaSection key={s.key} title={m.title} icon={m.icon} href={m.href} dramas={s.dramas} />;
      })}
    </div>
  );
}

function HomeSkeleton() {
  return (
    <div className="space-y-12">
      <div className="grid gap-[22px] lg:grid-cols-[62fr_38fr]">
        <div className="skeleton h-[360px] rounded-[2px] lg:h-[530px]" />
        <div className="hidden gap-[22px] sm:grid sm:grid-cols-2 lg:grid-cols-1">
          <div className="skeleton h-[200px] rounded-[2px] lg:h-[254px]" />
          <div className="skeleton h-[200px] rounded-[2px] lg:h-[254px]" />
        </div>
      </div>
      <div>
        <div className="skeleton mb-5 h-8 w-44 rounded" />
        <div className={gridClass}>
          {Array.from({ length: 6 }).map((_, i) => (
            <PosterCardSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}
