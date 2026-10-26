"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useT } from "@/lib/i18n";
import type { Drama, HomeData } from "@/lib/types";
import { Icon } from "../ui/Icon";
import { SectionHeading } from "./DramaRow";

/**
 * "Endelea kutazama" (scope §02). Personal, so it is fetched in the browser with the viewer's
 * token; the server-rendered home page is shared by everyone.
 */
export function ContinueWatching() {
  const { user } = useAuth();
  const t = useT();
  const [items, setItems] = useState<Drama[]>([]);

  useEffect(() => {
    if (!user) return;
    let alive = true;
    api
      .get<HomeData>("/home")
      .then((home) => {
        if (!alive) return;
        setItems(home.sections?.find((s) => s.key === "continue_watching")?.dramas ?? []);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [user]);

  if (!user || !items.length) return null;

  return (
    <section>
      <SectionHeading title="Continue watching" href="/account?tab=history" />
      <div className="scrollbar-none -mx-1 flex gap-4 overflow-x-auto px-1 pb-2">
        {items.map((d) => {
          const r = d.resume;
          const ep = r?.episode_number ?? 1;
          const pct = r && r.duration_seconds ? Math.min(100, Math.round((r.progress_seconds / r.duration_seconds) * 100)) : 0;
          return (
            <Link key={d.id} href={`/drama/${d.slug}/ep/${ep}`} className="group w-[150px] shrink-0 sm:w-[180px]">
              <div className="relative aspect-[3/4] overflow-hidden rounded-[8px] bg-surface">
                {d.poster_url && <Image src={d.poster_url} alt={d.title} fill sizes="180px" className="object-cover transition duration-200 group-hover:scale-[1.03]" />}
                <div className="absolute inset-0 grid place-items-center bg-black/25 opacity-0 transition group-hover:opacity-100">
                  <span className="grid h-11 w-11 place-items-center rounded-full bg-primary text-white">
                    <Icon name="play" size={18} />
                  </span>
                </div>
                <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 to-transparent px-2 pb-2 pt-6">
                  <p className="text-xs font-bold text-white">{t("EP {n}", { n: ep })}</p>
                  <div className="mt-1.5 h-1 overflow-hidden rounded-full bg-white/25">
                    <div className="h-full rounded-full bg-primary" style={{ width: `${Math.max(pct, 3)}%` }} />
                  </div>
                </div>
              </div>
              <p className="mt-2 line-clamp-2 text-sm font-semibold leading-snug group-hover:text-primary">{d.title}</p>
            </Link>
          );
        })}
      </div>
    </section>
  );
}
