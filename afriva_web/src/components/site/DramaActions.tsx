"use client";

import { useRouter } from "@/lib/navigation";
import { createContext, useContext, useEffect, useState } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn } from "@/lib/format";
import type { DramaDetail, Episode } from "@/lib/types";
import { buttonClass } from "../ui/Button";
import { Icon } from "../ui/Icon";
import Link from "next/link";
import { EpisodeGrid } from "./EpisodeGrid";

interface Personal {
  drama: DramaDetail;
  episodes: Episode[];
  isFavorite: boolean;
  favBusy: boolean;
  toggleFavorite: () => void;
}

const Ctx = createContext<Personal | null>(null);

/**
 * Personalised parts of the drama page: My List state and per-user unlock state
 * (refetched with the auth token). Consumed by <DramaButtons/> and <DramaEpisodes/>.
 */
export function DramaPersonalProvider({ drama, children }: { drama: DramaDetail; children: React.ReactNode }) {
  const { user } = useAuth();
  const router = useRouter();
  const [personal, setPersonal] = useState<{ episodes: Episode[]; is_favorite: boolean } | null>(null);
  const [favBusy, setFavBusy] = useState(false);
  const t = useT().site.drama;

  useEffect(() => {
    if (!user) return;
    let alive = true;
    api
      .get<DramaDetail>(`/dramas/${drama.slug}`)
      .then((d) => alive && setPersonal({ episodes: d.episodes ?? [], is_favorite: !!d.is_favorite }))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [user, drama.slug]);

  const episodes = (user && personal?.episodes) || drama.episodes || [];
  const isFavorite = user ? (personal?.is_favorite ?? drama.is_favorite) : false;

  const toggleFavorite = async () => {
    if (!user) {
      router.push(`/login?next=/drama/${drama.slug}`);
      return;
    }
    setFavBusy(true);
    const next = !isFavorite;
    setPersonal((p) => ({ episodes: p?.episodes ?? episodes, is_favorite: next }));
    try {
      await api.post(`/me/favorites/${drama.id}`);
      toast.success(next ? t.added : t.removed);
    } catch (e) {
      setPersonal((p) => ({ episodes: p?.episodes ?? episodes, is_favorite: !next }));
      toast.error(errorMessage(e));
    } finally {
      setFavBusy(false);
    }
  };

  return <Ctx.Provider value={{ drama, episodes, isFavorite, favBusy, toggleFavorite }}>{children}</Ctx.Provider>;
}

function usePersonal() {
  const v = useContext(Ctx);
  if (!v) throw new Error("Wrap in <DramaPersonalProvider>");
  return v;
}

export function DramaButtons() {
  const { drama, isFavorite, favBusy, toggleFavorite } = usePersonal();
  const t = useT().site.drama;
  const share = async () => {
    const url = window.location.href;
    try {
      if (navigator.share) await navigator.share({ title: drama.title, url });
      else {
        await navigator.clipboard.writeText(url);
        toast.success(t.linkCopied);
      }
    } catch {
      /* dismissed */
    }
  };
  return (
    <div className="mt-6 flex w-full flex-wrap items-center justify-center gap-3 sm:justify-start lg:mt-8">
      <Link
        href={`/drama/${drama.slug}/ep/1`}
        className={buttonClass("primary", "lg", "w-full px-10 shadow-[0_12px_30px_-10px_rgba(233,2,4,0.7)] sm:w-auto")}
      >
        <Icon name="play" size={17} /> {t.play}
      </Link>
      <button
        onClick={toggleFavorite}
        disabled={favBusy}
        aria-pressed={isFavorite}
        className={cn(buttonClass("secondary", "lg", "flex-1 bg-text/10 hover:bg-text/15 sm:flex-none"), isFavorite && "text-primary")}
      >
        <Icon name={isFavorite ? "bookmark-filled" : "bookmark"} size={18} />
        {isFavorite ? t.inList : t.addToList}
      </button>
      <button onClick={share} className={buttonClass("secondary", "lg", "w-12 bg-text/10 px-0! hover:bg-text/15")} aria-label={t.share}>
        <Icon name="share" size={18} />
      </button>
    </div>
  );
}

export function DramaEpisodes() {
  const { drama, episodes } = usePersonal();
  const t = useT().site.drama;
  return (
    <section id="episodes" className="scroll-mt-24">
      <div className="mb-5 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <h2 className="text-xl font-bold tracking-tight lg:text-2xl">
          {t.episodes} <span className="ml-1 text-base font-medium text-text-dim">{drama.total_episodes}</span>
        </h2>
        <p className="text-[13px] text-text-dim">
          {fmt(t.freeInfo, { free: drama.free_episodes, coins: drama.coins_per_episode })}
        </p>
      </div>
      <EpisodeGrid slug={drama.slug} episodes={episodes} />
    </section>
  );
}
