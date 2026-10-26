import Link from "next/link";
import { T } from "@/lib/i18n";
import type { Drama } from "@/lib/types";
import { Icon, type IconName } from "../ui/Icon";
import { PosterCard, gridClass } from "./PosterCard";

export function SectionHeading({ title, href }: { title: string; href?: string; icon?: IconName }) {
  return (
    <div className="mb-5 flex items-center justify-between gap-4">
      <h2 className="text-2xl font-bold tracking-tight text-text lg:text-[34px] lg:leading-tight">
        <T>{title}</T>
      </h2>
      {href && (
        <Link href={href} className="flex shrink-0 items-center gap-0.5 text-[15px] text-text transition-colors hover:text-primary lg:text-[19px]">
          <T>More</T> <Icon name="chevron-right" size={20} />
        </Link>
      )}
    </div>
  );
}

/** Section = icon + title + "More >" header over a uniform card grid. */
export function DramaSection({
  title,
  href,
  icon,
  dramas,
  limit = 6,
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
      <div className={gridClass}>
        {dramas.slice(0, limit).map((d, i) => (
          <PosterCard key={d.id} drama={d} className={i >= 4 ? "sm:max-lg:hidden" : undefined} />
        ))}
      </div>
    </section>
  );
}
