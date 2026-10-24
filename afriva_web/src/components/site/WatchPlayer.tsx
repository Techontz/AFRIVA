"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { ApiError, api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatCompact, formatNumber } from "@/lib/format";
import type { DramaDetail, Episode, PlayData, UnlockInfo } from "@/lib/types";
import { Button, buttonClass } from "../ui/Button";
import { ApiDownState, EmptyState, Spinner } from "../ui/Feedback";
import { Toggle } from "../ui/Form";
import { Icon } from "../ui/Icon";
import { Modal } from "../ui/Modal";
import { EpisodeGrid } from "./EpisodeGrid";

type PlayState =
  | { kind: "loading" }
  | { kind: "ready"; play: PlayData }
  | { kind: "locked"; message: string; unlock: UnlockInfo | null }
  | { kind: "error"; message: string };

const AUTOPLAY_KEY = "afriva_autoplay";

function readAutoplay() {
  if (typeof window === "undefined") return true;
  try {
    return window.localStorage.getItem(AUTOPLAY_KEY) !== "0";
  } catch {
    return true;
  }
}

export function WatchPlayer({ slug, initialNumber }: { slug: string; initialNumber: number }) {
  const { user, loading: authLoading, refresh, setUser } = useAuth();
  const [drama, setDrama] = useState<DramaDetail | null>(null);
  const [dramaError, setDramaError] = useState<{ status: number } | null>(null);
  const [number, setNumber] = useState(initialNumber);
  const [state, setState] = useState<PlayState>({ kind: "loading" });
  const [autoplay, setAutoplay] = useState(readAutoplay);
  const [paywallOpen, setPaywallOpen] = useState(false);
  const [unlocking, setUnlocking] = useState<"coins" | "episode_pack" | null>(null);
  const [panelOpen, setPanelOpen] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const lastSaved = useRef(0);

  // 1) Drama + episode list (personalised when logged in).
  useEffect(() => {
    if (authLoading) return;
    let alive = true;
    api
      .get<DramaDetail>(`/dramas/${encodeURIComponent(slug)}`)
      .then((d) => alive && setDrama(d))
      .catch((e: ApiError) => alive && setDramaError({ status: e?.status ?? 0 }));
    return () => {
      alive = false;
    };
  }, [slug, authLoading, user?.id]);

  const episodes = drama?.episodes ?? [];
  const episode = episodes.find((e) => e.number === number) ?? null;
  const episodeId = episode?.id;

  // 2) Play URL for the current episode (402 => paywall).
  useEffect(() => {
    if (!episodeId) return;
    let alive = true;
    api
      .get<PlayData>(`/episodes/${episodeId}/play`)
      .then((play) => {
        if (!alive) return;
        setState({ kind: "ready", play });
        setPaywallOpen(false);
      })
      .catch((e: unknown) => {
        if (!alive) return;
        if (e instanceof ApiError && e.status === 402) {
          setState({
            kind: "locked",
            message: e.message,
            unlock: (e.body.unlock as UnlockInfo | undefined) ?? null,
          });
          setPaywallOpen(true);
        } else {
          setState({ kind: "error", message: errorMessage(e) });
        }
      });
    return () => {
      alive = false;
    };
  }, [episodeId, user?.id]);

  const goTo = useCallback(
    (n: number) => {
      if (!drama || n === number) return;
      setState({ kind: "loading" });
      setNumber(n);
      lastSaved.current = 0;
      window.history.pushState(null, "", `/drama/${drama.slug}/ep/${n}`);
      window.scrollTo({ top: 0, behavior: "smooth" });
    },
    [drama, number],
  );

  // Browser back/forward between episodes.
  useEffect(() => {
    const onPop = () => {
      const m = window.location.pathname.match(/\/ep\/(\d+)/);
      if (m) {
        setState({ kind: "loading" });
        setNumber(Number(m[1]));
      }
    };
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, []);

  const numberOf = (id: number | null | undefined) => episodes.find((e) => e.id === id)?.number ?? null;
  const sortedNumbers = episodes.map((e) => e.number).sort((a, b) => a - b);
  const play = state.kind === "ready" ? state.play : null;
  const nextNumber =
    (play && numberOf(play.next_episode_id)) ?? sortedNumbers.find((n) => n > number) ?? null;
  const prevNumber =
    (play && numberOf(play.prev_episode_id)) ?? [...sortedNumbers].reverse().find((n) => n < number) ?? null;

  const saveProgress = useCallback(
    (force = false) => {
      const v = videoRef.current;
      if (!user || !episodeId || !v) return;
      const t = Math.floor(v.currentTime);
      if (!force && Math.abs(t - lastSaved.current) < 15) return;
      lastSaved.current = t;
      api.post(`/episodes/${episodeId}/progress`, { progress_seconds: t }).catch(() => {});
    },
    [user, episodeId],
  );

  const onEnded = () => {
    saveProgress(true);
    if (autoplay && nextNumber) goTo(nextNumber);
  };

  // Keyboard shortcuts: ←/→ seek handled natively; N / P for next / previous.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      if (e.key === "n" && nextNumber) goTo(nextNumber);
      if (e.key === "p" && prevNumber) goTo(prevNumber);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [nextNumber, prevNumber, goTo]);

  const unlock = async (method: "coins" | "episode_pack") => {
    if (!episodeId) return;
    setUnlocking(method);
    try {
      await api.post(`/episodes/${episodeId}/unlock`, { method });
      toast.success(`Episode ${number} unlocked`);
      setDrama((d) =>
        d ? { ...d, episodes: d.episodes.map((e) => (e.id === episodeId ? { ...e, is_unlocked: true } : e)) } : d,
      );
      if (method === "coins" && state.kind === "locked" && state.unlock) {
        const spent = state.unlock.coins_required;
        setUser((u) => (u ? { ...u, coins: Math.max(0, u.coins - spent) } : u));
      }
      refresh();
      const playData = await api.get<PlayData>(`/episodes/${episodeId}/play`);
      setState({ kind: "ready", play: playData });
      setPaywallOpen(false);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setUnlocking(null);
    }
  };

  const toggleAutoplay = (v: boolean) => {
    setAutoplay(v);
    try {
      window.localStorage.setItem(AUTOPLAY_KEY, v ? "1" : "0");
    } catch {
      /* ignore */
    }
  };

  if (dramaError) {
    return (
      <div className="mx-auto max-w-3xl px-4 pt-16">
        {dramaError.status === 404 ? (
          <EmptyState
            title="This drama isn't available"
            description="It may have been removed or the link is wrong."
            action={<Button href="/browse">Browse dramas</Button>}
          />
        ) : (
          <ApiDownState />
        )}
      </div>
    );
  }

  if (!drama) return <WatchSkeleton />;

  if (!episode) {
    return (
      <div className="mx-auto max-w-3xl px-4 pt-16">
        <EmptyState
          title={`Episode ${number} isn't out yet`}
          description="New episodes drop regularly — start from the beginning or pick another."
          action={<Button href={`/drama/${drama.slug}`}>Back to {drama.title}</Button>}
        />
      </div>
    );
  }

  const unlockInfo = state.kind === "locked" ? state.unlock : null;
  const coinsRequired = unlockInfo?.coins_required ?? drama.coins_per_episode;
  const userCoins = user ? (unlockInfo?.user_coins ?? user.coins) : 0;

  return (
    <div className="relative">
      <div className="mx-auto flex max-w-[1280px] flex-col gap-6 px-0 pb-6 sm:px-6 sm:pt-6 lg:flex-row lg:items-start lg:justify-center lg:gap-8 lg:px-8">
        {/* Player column */}
        <div className="flex flex-col items-center lg:sticky lg:top-[112px]">
          <div
            className="chrome-dark relative aspect-[9/16] w-full overflow-hidden bg-black sm:w-auto sm:rounded-2xl sm:ring-1 sm:ring-white/10"
            style={{ height: "min(calc(100dvh - 9rem), 860px)", maxWidth: "100%" }}
          >
            {state.kind === "ready" ? (
              <video
                key={state.play.video_url}
                ref={videoRef}
                src={state.play.video_url}
                poster={episode.thumbnail_url ?? undefined}
                className="h-full w-full bg-black object-contain"
                controls
                autoPlay
                playsInline
                controlsList="nodownload"
                onTimeUpdate={() => saveProgress()}
                onPause={() => saveProgress(true)}
                onEnded={onEnded}
              />
            ) : (
              <div className="absolute inset-0">
                {drama.poster_url && (
                  <Image src={drama.poster_url} alt="" fill sizes="480px" className="object-cover opacity-40 blur-sm" />
                )}
                <div className="absolute inset-0 grid place-items-center bg-black/40">
                  {state.kind === "loading" && <Spinner size={36} className="text-white" />}
                  {state.kind === "locked" && (
                    <div className="flex flex-col items-center gap-4 px-6 text-center">
                      <span className="grid h-16 w-16 place-items-center rounded-full bg-black/60 text-primary ring-1 ring-white/30">
                        <Icon name="lock" size={28} />
                      </span>
                      <p className="text-lg font-bold">Episode {number} is locked</p>
                      <Button onClick={() => setPaywallOpen(true)}>Unlock to keep watching</Button>
                    </div>
                  )}
                  {state.kind === "error" && (
                    <div className="flex flex-col items-center gap-3 px-6 text-center">
                      <Icon name="alert" size={32} className="text-danger" />
                      <p className="text-sm text-text-muted">{state.message}</p>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Episode label */}
            <div className="pointer-events-none absolute left-0 right-0 top-0 bg-gradient-to-b from-black/70 to-transparent p-4">
              <p className="truncate text-sm font-bold">{drama.title}</p>
              <p className="text-xs text-white/70">
                EP {number}
                {episode.title ? ` · ${episode.title}` : ""}
              </p>
            </div>
          </div>

          {/* Prev / next bar */}
          <div className="mt-3 flex w-full items-center justify-between gap-2 px-4 sm:px-0">
            <button
              onClick={() => prevNumber && goTo(prevNumber)}
              disabled={!prevNumber}
              className={buttonClass("secondary", "sm")}
            >
              <Icon name="skip-prev" size={15} /> Prev
            </button>
            <button onClick={() => setPanelOpen(true)} className={buttonClass("ghost", "sm", "lg:hidden")}>
              <Icon name="list" size={16} /> Episodes
            </button>
            <button
              onClick={() => nextNumber && goTo(nextNumber)}
              disabled={!nextNumber}
              className={buttonClass("secondary", "sm")}
            >
              Next <Icon name="skip-next" size={15} />
            </button>
          </div>
        </div>

        {/* Info + episode panel */}
        <aside className={cn("w-full px-4 sm:px-0 lg:w-[400px] lg:shrink-0")}>
          <EpisodePanel
            drama={drama}
            number={number}
            onSelect={(ep) => goTo(ep.number)}
            autoplay={autoplay}
            onAutoplay={toggleAutoplay}
          />
        </aside>
      </div>

      {/* Mobile episode sheet */}
      <Modal open={panelOpen} onClose={() => setPanelOpen(false)} title={`Episodes · ${drama.total_episodes}`}>
        <EpisodeGrid
          slug={drama.slug}
          episodes={episodes}
          current={number}
          compact
          onSelect={(ep) => {
            setPanelOpen(false);
            goTo(ep.number);
          }}
        />
      </Modal>

      {/* Paywall */}
      <Modal open={paywallOpen} onClose={() => setPaywallOpen(false)} size="sm" hideClose title={null}>
        <div className="-mt-1 text-center">
          <div className="mx-auto mt-6 grid h-16 w-16 place-items-center rounded-2xl bg-primary text-white">
            <Icon name="crown" size={30} strokeWidth={2} />
          </div>
          <h2 className="mt-4 text-xl font-extrabold">Unlock Episode {number}</h2>
          <p className="mt-1 text-sm text-text-muted">
            {drama.title} — EP 1–{drama.free_episodes} are free. Keep the story going:
          </p>

          {!user ? (
            <div className="mt-6 space-y-2.5">
              <Button href={`/login?next=${encodeURIComponent(`/drama/${drama.slug}/ep/${number}`)}`} className="w-full" size="lg">
                Log in to continue
              </Button>
              <Button href="/vip" variant="gold" className="w-full" size="lg">
                <Icon name="crown" size={17} /> Subscribe VIP
              </Button>
            </div>
          ) : (
            <div className="mt-6 space-y-2.5">
              <Button
                href={`/vip?next=${encodeURIComponent(`/drama/${drama.slug}/ep/${number}`)}`}
                variant="gold"
                className="w-full"
                size="lg"
              >
                <Icon name="crown" size={17} /> Subscribe VIP — watch everything
              </Button>
              <Button
                onClick={() => unlock("coins")}
                loading={unlocking === "coins"}
                disabled={!!unlocking || userCoins < coinsRequired}
                variant="primary"
                className="w-full"
                size="lg"
              >
                <Icon name="coin" size={17} /> Unlock for {formatNumber(coinsRequired)} coins
              </Button>
              {unlockInfo?.can_use_pack && (
                <Button
                  onClick={() => unlock("episode_pack")}
                  loading={unlocking === "episode_pack"}
                  disabled={!!unlocking}
                  variant="secondary"
                  className="w-full"
                  size="lg"
                >
                  <Icon name="layers" size={17} /> Use my episode pack
                </Button>
              )}
              <p className="pt-1 text-xs text-text-dim">
                Your balance: <span className="font-bold text-primary">{formatNumber(userCoins)} coins</span>
                {userCoins < coinsRequired && (
                  <>
                    {" · "}
                    <Link href="/vip#coins" className="font-semibold text-primary hover:underline">
                      Top up coins
                    </Link>
                  </>
                )}
              </p>
            </div>
          )}
          <button
            onClick={() => setPaywallOpen(false)}
            className="mt-4 text-sm font-semibold text-text-dim transition hover:text-text"
          >
            Not now
          </button>
        </div>
      </Modal>
    </div>
  );
}

function EpisodePanel({
  drama,
  number,
  onSelect,
  autoplay,
  onAutoplay,
}: {
  drama: DramaDetail;
  number: number;
  onSelect: (ep: Episode) => void;
  autoplay: boolean;
  onAutoplay: (v: boolean) => void;
}) {
  return (
    <div className="space-y-5">
      <div className="rounded-2xl border border-border bg-surface p-5">
        <Link href={`/drama/${drama.slug}`} className="group flex items-start gap-3">
          <div className="relative aspect-[3/4] w-14 shrink-0 overflow-hidden rounded-md bg-surface-2">
            {drama.poster_url && <Image src={drama.poster_url} alt="" fill sizes="56px" className="object-cover" />}
          </div>
          <div className="min-w-0">
            <h1 className="line-clamp-2 text-lg font-extrabold leading-snug group-hover:text-primary">{drama.title}</h1>
            <p className="mt-1 text-xs text-text-dim">
              EP {number} / {drama.total_episodes} · {formatCompact(drama.views)} views
            </p>
          </div>
        </Link>
        <p className="mt-4 line-clamp-4 text-sm leading-relaxed text-text-muted">{drama.synopsis}</p>
        <div className="mt-4 flex items-center justify-between border-t border-border pt-4">
          <span className="text-sm font-semibold text-text-muted">Autoplay next episode</span>
          <Toggle checked={autoplay} onChange={onAutoplay} label="Autoplay next episode" size="sm" />
        </div>
      </div>

      <div className="hidden rounded-2xl border border-border bg-surface p-5 lg:block">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-bold">Episodes</h2>
          <span className="text-xs text-text-dim">{drama.total_episodes} total</span>
        </div>
        <EpisodeGrid key={drama.id} slug={drama.slug} episodes={drama.episodes} current={number} onSelect={onSelect} compact />
      </div>
    </div>
  );
}

function WatchSkeleton() {
  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-6 sm:px-6 sm:pt-6 lg:flex-row lg:justify-center lg:gap-8">
      <div className="skeleton mx-auto aspect-[9/16] w-full sm:w-auto sm:rounded-2xl" style={{ height: "min(calc(100dvh - 9rem), 860px)", maxWidth: "100%" }} />
      <div className="w-full space-y-4 px-4 sm:px-0 lg:w-[400px]">
        <div className="skeleton h-40 rounded-2xl" />
        <div className="skeleton h-72 rounded-2xl" />
      </div>
    </div>
  );
}
