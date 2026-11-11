import Link from "next/link";
import { getDict } from "@/i18n/server";
import type { Drama } from "@/lib/types";
import { Icon, type IconName } from "../ui/Icon";
import { PosterCard, shelfItemClass } from "./PosterCard";
import { Scroller } from "./Scroller";

export async function SectionHeading({ title, href }: { title: string; href?: string; icon?: IconName }) {
  const t = (await getDict()).site.card;
  return (
    <div className="mb-4 flex items-baseline justify-between gap-4 lg:mb-5">
      <h2 className="text-xl font-bold tracking-tight text-text lg:text-2xl">{title}</h2>
      {href && (
        <Link href={href} className="flex shrink-0 items-center gap-0.5 text-[13px] font-medium text-text-muted transition-colors hover:text-text lg:text-sm">
          {t.seeAll} <Icon name="chevron-right" size={16} />
        </Link>
      )}
    </div>
  );
}

/** Row title with a quiet "See all" over a horizontally scrolling shelf of posters. */
export function DramaSection({
  title,
  href,
  icon,
  dramas,
  limit = 14,
}: {
  title: string;
  href?: string;
  icon?: IconName;
  dramas: Drama[];
  limit?: number;
}) {
  if (!dramas.length) return null;
  return (
    <section>
      <SectionHeading title={title} href={href} icon={icon} />
      <Scroller label={title}>
        {dramas.slice(0, limit).map((d) => (
          <PosterCard key={d.id} drama={d} className={shelfItemClass} />
        ))}
      </Scroller>
    </section>
  );
}
