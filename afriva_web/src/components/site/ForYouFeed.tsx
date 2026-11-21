"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "@/lib/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt, plural } from "@/i18n/format";
import { api, errorMessage, normalizePage, request } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatCompact } from "@/lib/format";
import type { FeedItem } from "@/lib/types";
import { Button } from "../ui/Button";
import { ApiDownState, EmptyState, Spinner } from "../ui/Feedback";
import { Icon } from "../ui/Icon";
import { GenreChips, dramaGenres, genreName } from "./PosterCard";
import { StreamVideo } from "./StreamVideo";

const PER_PAGE = 8;

export function ForYouFeed() {
  const { user } = useAuth();
  const { common: tc, user: tu } = useT();
  const t = tu.feed;
  const { categories } = useT().site.card;
  const router = useRouter();
  const [items, setItems] = useState<FeedItem[]>([]);
  const [page, setPage] = useState(0);
  const [lastPage, setLastPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [active, setActive] = useState(0);
  const [muted, setMuted] = useState(true);
  const [favorites, setFavorites] = useState<Record<number, boolean>>({});
  const scroller = useRef<HTMLDivElement>(null);
  const videos = useRef(new Map<number, HTMLVideoElement>());
  const loadingRef = useRef(false);

  const load = useCallback(async (p: number) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    queueMicrotask(() => setLoading(true));
    try {
      const res = await request<unknown>("/feed", { query: { page: p, per_page: PER_PAGE } });
      const { items: next, meta } = normalizePage<FeedItem>(res);
      setItems((prev) => {
        const seen = new Set(prev.map((i) => i.drama.id));
        return [...prev, ...next.filter((i) => !seen.has(i.drama.id))];
      });
      setPage(p);
      setLastPage(meta.last_page);
      setError(false);
    } catch {
      setError(true);
    } finally {
      loadingRef.current = false;
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const t = setTimeout(() => load(1), 0);
    return () => clearTimeout(t);
  }, [load]);

  // Track which item is centred.
  useEffect(() => {
    const root = scroller.current;
    if (!root) return;
    const obs = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) setActive(Number((e.target as HTMLElement).dataset.index));
        }
      },
      { root, threshold: 0.6 },
    );
    root.querySelectorAll("[data-index]").forEach((el) => obs.observe(el));
    return () => obs.disconnect();
  }, [items.length]);

  // Play the active video, pause the rest; prefetch more near the end.
  useEffect(() => {
    videos.current.forEach((v, idx) => {
      if (idx === active) v.play().catch(() => {});
      else v.pause();
    });
    if (active >= items.length - 3 && page < lastPage && !loading) {
      const t = setTimeout(() => load(page + 1), 0);
      return () => clearTimeout(t);
    }
  }, [active, items.length, page, lastPage, loading, load]);

  const scrollTo = (idx: number) => {
    const el = scroller.current?.querySelector<HTMLElement>(`[data-index="${idx}"]`);
    el?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;
      if (e.key === "ArrowDown" || e.key === "j") {
        e.preventDefault();
        scrollTo(Math.min(active + 1, items.length - 1));
      } else if (e.key === "ArrowUp" || e.key === "k") {
        e.preventDefault();
        scrollTo(Math.max(active - 1, 0));
      } else if (e.key === "m") setMuted((m) => !m);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active, items.length]);

  const toggleFavorite = async (item: FeedItem) => {
    if (!user) {
      router.push("/login?next=/foryou");
      return;
    }
    const id = item.drama.id;
    const next = !(favorites[id] ?? item.drama.is_favorite);
    setFavorites((f) => ({ ...f, [id]: next }));
    try {
      await api.post(`/me/favorites/${id}`);
      toast.success(next ? t.added : t.removed);
    } catch (e) {
      setFavorites((f) => ({ ...f, [id]: !next }));
      toast.error(errorMessage(e));
    }
  };

  const share = async (item: FeedItem) => {
    const url = `${window.location.origin}/drama/${item.drama.slug}`;
    try {
      if (navigator.share) await navigator.share({ title: item.drama.title, url });
      else {
        await navigator.clipboard.writeText(url);
        toast.success(t.linkCopied);
      }
    } catch {
      /* dismissed */
    }
  };

  if (error && !items.length) {
    return (
      <div className="mx-auto max-w-3xl px-4 pt-16">
        <ApiDownState action={<Button variant="secondary" onClick={() => load(1)}>{t.retry}</Button>} />
      </div>
    );
  }
  if (loading && !items.length) {
    return (
      <div className="chrome-dark grid h-[calc(100dvh-var(--header-h)-var(--tabbar-h))] place-items-center bg-black text-text-muted">
        <Spinner size={32} />
      </div>
    );
  }
  if (!loading && !items.length) {
    return (
      <div className="mx-auto max-w-3xl px-4 pt-16">
        <EmptyState title={t.emptyTitle} description={t.emptyBody} />
      </div>
    );
  }

  return (
    <div className="chrome-dark relative bg-black">
      <div
        ref={scroller}
        className="scrollbar-none h-[calc(100dvh-var(--header-h)-var(--tabbar-h))] snap-y snap-mandatory overflow-y-auto overscroll-contain"
        aria-label={t.label}
      >
        {items.map((item, idx) => {
          const near = Math.abs(idx - active) <= 1;
          const fav = favorites[item.drama.id] ?? item.drama.is_favorite;
          const d = item.drama;
          return (
            <section
              key={d.id}
              data-index={idx}
              aria-label={d.title}
              className="relative flex h-[calc(100dvh-var(--header-h)-var(--tabbar-h))] snap-start snap-always items-center justify-center py-0 sm:py-4"
            >
              <div className="relative aspect-[9/16] h-full max-w-full overflow-hidden bg-black sm:rounded-2xl sm:ring-1 sm:ring-white/10">
                {near && item.episode.video_url ? (
                  <StreamVideo
                    ref={(el) => {
                      if (el) videos.current.set(idx, el);
                      else videos.current.delete(idx);
                    }}
                    src={item.episode.video_url}
                    poster={item.episode.thumbnail_url ?? d.poster_url}
                    className="h-full w-full object-cover"
                    muted={muted}
                    loop
                    playsInline
                    preload={idx === active ? "auto" : "metadata"}
                    onClick={(e) => {
                      const v = e.currentTarget;
                      if (v.paused) v.play().catch(() => {});
                      else v.pause();
                    }}
                  />
                ) : (
                  d.poster_url && <Image src={d.poster_url} alt="" fill sizes="480px" className="object-cover" />
                )}
                {!item.episode.video_url && (
                  <div className="absolute inset-x-0 top-1/3 flex justify-center">
                    <span className="flex items-center gap-1.5 rounded-full bg-black/60 px-3.5 py-1.5 text-xs font-bold backdrop-blur">
                      <Icon name="clock" size={14} className="text-primary" /> {t.comingSoon}
                    </span>
                  </div>
                )}

                <div className="pointer-events-none absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-black/90 via-black/40 to-transparent" />

                {/* Right-side actions */}
                <div className="absolute bottom-28 right-3 flex flex-col items-center gap-5">
                  <button onClick={() => toggleFavorite(item)} className="flex flex-col items-center gap-1 text-[11px] font-semibold" aria-pressed={fav} aria-label={t.myList}>
                    <span className={cn("grid h-11 w-11 place-items-center rounded-full bg-black/50 backdrop-blur transition", fav && "text-primary")}>
                      <Icon name={fav ? "bookmark-filled" : "bookmark"} size={22} />
                    </span>
                    {t.myList}
                  </button>
                  <Link href={`/drama/${d.slug}#episodes`} className="flex flex-col items-center gap-1 text-[11px] font-semibold" aria-label={t.episodes}>
                    <span className="grid h-11 w-11 place-items-center rounded-full bg-black/50 backdrop-blur">
                      <Icon name="list" size={22} />
                    </span>
                    {t.episodes}
                  </Link>
                  <button onClick={() => share(item)} className="flex flex-col items-center gap-1 text-[11px] font-semibold" aria-label={t.share}>
                    <span className="grid h-11 w-11 place-items-center rounded-full bg-black/50 backdrop-blur">
                      <Icon name="share" size={20} />
                    </span>
                    {t.share}
                  </button>
                  <button onClick={() => setMuted((m) => !m)} className="grid h-11 w-11 place-items-center rounded-full bg-black/50 backdrop-blur" aria-label={muted ? t.unmute : t.mute}>
                    <Icon name={muted ? "mute" : "volume"} size={20} />
                  </button>
                </div>

                {/* Bottom info */}
                <div className="absolute inset-x-0 bottom-0 p-4 pr-20">
                  <p className="text-xs font-semibold text-white/70">
                    {t.firstEp} · {plural(d.total_episodes, tc.episodes)} · {fmt(t.views, { n: formatCompact(d.views) })}
                  </p>
                  <h2 className="mt-1 line-clamp-2 text-lg font-extrabold leading-snug">{d.title}</h2>
                  <p className="mt-1 line-clamp-2 text-[13px] text-white/75">{d.synopsis}</p>
                  <GenreChips names={dramaGenres(d).map((g) => genreName(g, categories))} className="mt-2" />
                  <Link
                    href={`/drama/${d.slug}/ep/${d.total_episodes > 1 ? 2 : 1}`}
                    className="mt-3 flex items-center justify-between rounded-xl bg-white/10 px-3 py-2.5 text-sm font-bold backdrop-blur transition hover:bg-white/20"
                  >
                    <span className="flex items-center gap-2">
                      <Icon name="play" size={14} className="text-primary" /> {t.watchFull}
                    </span>
                    <Icon name="chevron-right" size={18} />
                  </Link>
                </div>
              </div>
            </section>
          );
        })}
        {loading && (
          <div className="flex h-40 items-center justify-center text-text-muted">
            <Spinner />
          </div>
        )}
      </div>

      {/* Desktop up/down controls */}
      <div className="absolute right-6 top-1/2 hidden -translate-y-1/2 flex-col gap-2 lg:flex">
        <button
          onClick={() => scrollTo(Math.max(active - 1, 0))}
          disabled={active === 0}
          className="grid h-11 w-11 place-items-center rounded-full bg-surface-2 text-text transition hover:bg-surface-3 disabled:opacity-30"
          aria-label={t.prevDrama}
        >
          <Icon name="chevron-up" />
        </button>
        <button
          onClick={() => scrollTo(Math.min(active + 1, items.length - 1))}
          disabled={active >= items.length - 1}
          className="grid h-11 w-11 place-items-center rounded-full bg-surface-2 text-text transition hover:bg-surface-3 disabled:opacity-30"
          aria-label={t.nextDrama}
        >
          <Icon name="chevron-down" />
        </button>
      </div>
    </div>
  );
}
