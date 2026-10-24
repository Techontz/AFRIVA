"use client";

import { useRouter } from "next/navigation";
import { createContext, useContext, useEffect, useState } from "react";
import { toast } from "sonner";
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
      toast.success(next ? "Added to My List" : "Removed from My List");
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
  const share = async () => {
    const url = window.location.href;
    try {
      if (navigator.share) await navigator.share({ title: drama.title, url });
      else {
        await navigator.clipboard.writeText(url);
        toast.success("Link copied");
      }
    } catch {
      /* dismissed */
    }
  };
  return (
    <div className="mt-6 flex flex-wrap gap-3">
      <Link href={`/drama/${drama.slug}/ep/1`} className={buttonClass("primary", "lg")}>
        <Icon name="play" size={16} /> Play
      </Link>
      <button
        onClick={toggleFavorite}
        disabled={favBusy}
        aria-pressed={isFavorite}
        className={cn(buttonClass("secondary", "lg"), isFavorite && "text-primary")}
      >
        <Icon name={isFavorite ? "bookmark-filled" : "bookmark"} size={18} />
        {isFavorite ? "In My List" : "Add to My List"}
      </button>
      <button onClick={share} className={buttonClass("secondary", "lg", "w-12 px-0!")} aria-label="Share">
        <Icon name="share" size={18} />
      </button>
    </div>
  );
}

export function DramaEpisodes() {
  const { drama, episodes } = usePersonal();
  return (
    <section id="episodes" className="scroll-mt-20">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-2">
        <h2 className="flex items-center gap-2 text-lg font-extrabold sm:text-xl">
          <Icon name="list" size={18} className="text-primary" /> Episodes
          <span className="text-sm font-semibold text-text-dim">({drama.total_episodes})</span>
        </h2>
        <p className="text-xs text-text-dim">
          EP 1–{drama.free_episodes} free · then {drama.coins_per_episode} coins or VIP
        </p>
      </div>
      <EpisodeGrid slug={drama.slug} episodes={episodes} />
    </section>
  );
}
