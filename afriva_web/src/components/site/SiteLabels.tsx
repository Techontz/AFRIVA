"use client";

import { useT } from "@/i18n/client";
import { plural } from "@/i18n/format";
import type { Drama } from "@/lib/types";
import { genreName } from "./PosterCard";

/** Text leaves for components that render in both server and client trees. */
export function EpisodeCount({ n }: { n: number }) {
  return <>{plural(n, useT().site.card.episodes)}</>;
}

export function BadgeText({ badge }: { badge: NonNullable<Drama["badge"]> }) {
  return <>{useT().site.card.badge[badge]}</>;
}

/** Card caption: "Hot · 72 Episodes · Billionaire"; the genre is dropped on phones to keep it on one line. */
export function CardMeta({ episodes, genre, badge }: { episodes: number; genre?: string; badge?: Drama["badge"] }) {
  const t = useT().site.card;
  return (
    <>
      {badge && <span className="font-semibold text-primary">{t.badge[badge]} · </span>}
      {plural(episodes, t.episodes)}
      {genre && <span className="hidden sm:inline"> · {genreName(genre, t.categories)}</span>}
    </>
  );
}
