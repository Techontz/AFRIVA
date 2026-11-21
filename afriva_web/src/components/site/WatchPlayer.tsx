"use client";

import Image from "next/image";
import Link from "next/link";
import { ProductionScene } from "./ProductionScene";
import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { ApiError, api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatCompact, formatNumber } from "@/lib/format";
import type { DramaDetail, Episode, PlayData, UnlockInfo } from "@/lib/types";
import { Button, buttonClass } from "../ui/Button";
import { ApiDownState, EmptyState, Spinner } from "../ui/Feedback";
import { Toggle } from "../ui/Form";
import { Icon } from "../ui/Icon";
import { useDismiss } from "../LanguageMenu";
import { Modal } from "../ui/Modal";
import { EpisodeGrid } from "./EpisodeGrid";
import { StreamVideo } from "./StreamVideo";

type PlayState =
  | { kind: "loading" }
  | { kind: "ready"; play: PlayData }
  | { kind: "soon"; play: PlayData } // episode exists but its video is not ready yet
  | { kind: "locked"; message: string; unlock: UnlockInfo | null }
  | { kind: "error"; message: string };

const AUTOPLAY_KEY = "afriva_autoplay";
const QUALITY_KEY = "afriva_quality";

/** A null `video_url` means the video is still uploading / encoding. */
const playState = (play: PlayData): PlayState => (play.video_url ? { kind: "ready", play } : { kind: "soon", play });

function readAutoplay() {
  if (typeof window === "undefined") return true;
  try {
    return window.localStorage.getItem(AUTOPLAY_KEY) !== "0";
  } catch {
    return true;
  }
}

/** Saved quality (short side in px), null = Auto. */
function readQuality(): number | null {
  if (typeof window === "undefined") return null;
  try {
    const v = Number(window.localStorage.getItem(QUALITY_KEY));
    return Number.isFinite(v) && v > 0 ? v : null;
  } catch {
    return null;
  }
}

export function WatchPlayer({ slug, initialNumber }: { slug: string; initialNumber: number }) {
  const { user, loading: authLoading, refresh, setUser } = useAuth();
  const t = useT().user.watch;
  const [drama, setDrama] = useState<DramaDetail | null>(null);
  const [dramaError, setDramaError] = useState<{ status: number } | null>(null);
  const [number, setNumber] = useState(initialNumber);
  const [state, setState] = useState<PlayState>({ kind: "loading" });
  const [autoplay, setAutoplay] = useState(readAutoplay);
  const [paywallOpen, setPaywallOpen] = useState(false);
  const [unlocking, setUnlocking] = useState<"coins" | "episode_pack" | null>(null);
  const [panelOpen, setPanelOpen] = useState(false);
  const [quality, setQuality] = useState<number | null>(readQuality);
  const [qualities, setQualities] = useState<number[]>([]);
  const [activeQuality, setActiveQuality] = useState<number | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const lastSaved = useRef(0);
  const numberRef = useRef(number);
  useEffect(() => {
    numberRef.current = number;
  }, [number]);

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
        setState(playState(play));
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
      if (!m) return;
      const n = Number(m[1]);
      // Only reset to "loading" when the episode actually changes; otherwise
      // the play effect won't re-run and the spinner would never clear.
      if (n === numberRef.current) return;
      setState({ kind: "loading" });
      setNumber(n);
    };
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, []);

  const numberOf = (id: number | null | undefined) => episodes.find((e) => e.id === id)?.number ?? null;
  const sortedNumbers = episodes.map((e) => e.number).sort((a, b) => a - b);
  const play = state.kind === "ready" || state.kind === "soon" ? state.play : null;
  const nextNumber =
    (play && numberOf(play.next_episode_id)) ?? sortedNumbers.find((n) => n > number) ?? null;
  const prevNumber =
    (play && numberOf(play.prev_episode_id)) ?? [...sortedNumbers].reverse().find((n) => n < number) ?? null;

  const saveProgress = useCallback(
    (force = false) => {
      const v = videoRef.current;
      if (!user || !episodeId || !v) return;
      const sec = Math.floor(v.currentTime);
      if (!force && Math.abs(sec - lastSaved.current) < 15) return;
      lastSaved.current = sec;
      api.post(`/episodes/${episodeId}/progress`, { progress_seconds: sec }).catch(() => {});
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
      toast.success(fmt(t.unlocked, { n: number }));
      setDrama((d) =>
        d ? { ...d, episodes: d.episodes.map((e) => (e.id === episodeId ? { ...e, is_unlocked: true } : e)) } : d,
      );
      if (method === "coins" && state.kind === "locked" && state.unlock) {
        const spent = state.unlock.coins_required;
        setUser((u) => (u ? { ...u, coins: Math.max(0, u.coins - spent) } : u));
      }
      refresh();
      const playData = await api.get<PlayData>(`/episodes/${episodeId}/play`);
      setState(playState(playData));
      setPaywallOpen(false);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setUnlocking(null);
    }
  };

  const chooseQuality = (q: number | null) => {
    setQuality(q);
    try {
      if (q) window.localStorage.setItem(QUALITY_KEY, String(q));
      else window.localStorage.removeItem(QUALITY_KEY);
    } catch {
      /* ignore */
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
            title={t.unavailable}
            description={t.unavailableHint}
            action={<Button href="/browse">{t.browse}</Button>}
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
          title={fmt(t.notOut, { n: number })}
          description={t.notOutHint}
          action={<Button href={`/drama/${drama.slug}`}>{fmt(t.backTo, { title: drama.title })}</Button>}
        />
      </div>
    );
  }

  const landscape = episode.orientation === "landscape";
  const unlockInfo = state.kind === "locked" ? state.unlock : null;
  const coinsRequired = unlockInfo?.coins_required ?? drama.coins_per_episode;
  const userCoins = user ? (unlockInfo?.user_coins ?? user.coins) : 0;

  return (
    <div className="relative -mt-(--header-h) pt-(--header-h)">
      {drama.poster_url && (
        <div className="pointer-events-none absolute inset-x-0 top-0 h-[70vh] overflow-hidden" aria-hidden>
          <Image src={drama.poster_url} alt="" fill loading="eager" sizes="100vw" className="scale-125 object-cover opacity-50 blur-3xl saturate-150 [:root[data-theme=light]_&]:opacity-30" />
          <div className="absolute inset-0 bg-gradient-to-b from-bg/40 to-bg" />
        </div>
      )}
      <div
        className={cn(
          "relative mx-auto flex max-w-[1280px] flex-col gap-6 px-0 pb-6 sm:px-6 sm:pt-6 lg:px-8",
          !landscape && "lg:flex-row lg:items-start lg:justify-center lg:gap-8",
        )}
      >
        {/* Player column */}
        <div className={cn("flex flex-col items-center", !landscape && "lg:sticky lg:top-[calc(var(--header-h)+1.5rem)]")}>
          <div
            className={cn(
              "chrome-dark relative w-full overflow-hidden bg-black sm:rounded-[20px] sm:shadow-[0_30px_70px_-30px_rgba(0,0,0,0.8)]",
              landscape ? "aspect-video" : "aspect-[9/16] sm:w-auto",
            )}
            style={landscape ? undefined : { height: "min(calc(100dvh - 9rem), 860px)", maxWidth: "100%" }}
          >
            {state.kind === "ready" && state.play.video_url ? (
              <StreamVideo
                key={state.play.video_url}
                ref={videoRef}
                src={state.play.video_url}
                quality={quality}
                onQualities={setQualities}
                onActiveQuality={setActiveQuality}
                onFatalError={() => setState({ kind: "error", message: t.playbackError })}
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
                  <Image src={drama.poster_url} alt="" fill loading="eager" sizes="480px" className="object-cover opacity-40 blur-sm" />
                )}
                <div className="absolute inset-0 grid place-items-center bg-black/40">
                  {state.kind === "loading" && <Spinner size={36} className="text-white" />}
                  {state.kind === "soon" && (
                    <div className="flex flex-col items-center gap-3 px-6 text-center">
                      <ProductionScene className="w-[220px] max-w-[70%]" />
                      <p className="text-lg font-bold">{t.comingSoon}</p>
                      <p className="max-w-[260px] text-sm text-white/70">{fmt(t.comingSoonHint, { n: number })}</p>
                      <span className="mt-1 flex gap-1.5" aria-hidden>
                        {[0, 1, 2].map((i) => (
                          <span key={i} className="h-1.5 w-1.5 animate-pulse rounded-full bg-primary" style={{ animationDelay: `${i * 200}ms` }} />
                        ))}
                      </span>
                    </div>
                  )}
                  {state.kind === "locked" && (
                    <div className="flex flex-col items-center gap-4 px-6 text-center">
                      <span className="grid h-16 w-16 place-items-center rounded-full bg-black/60 text-primary ring-1 ring-white/30">
                        <Icon name="lock" size={28} />
                      </span>
                      <p className="text-lg font-bold">{fmt(t.locked, { n: number })}</p>
                      <Button onClick={() => setPaywallOpen(true)}>{t.unlockCta}</Button>
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

            {state.kind === "ready" && qualities.length > 0 && (
              <QualityMenu qualities={qualities} value={quality} active={activeQuality} onChange={chooseQuality} />
            )}

            {/* Episode label; hidden during playback so it never sits over the poster's printed logo. */}
            {state.kind !== "ready" && <div className="pointer-events-none absolute left-0 right-0 top-0 bg-gradient-to-b from-black/70 to-transparent p-4 pr-16">
              <p className="truncate text-sm font-bold">{drama.title}</p>
              <p className="text-xs text-white/70">
                {fmt(t.epLabel, { n: number })}
                {episode.title ? ` · ${episode.title}` : ""}
              </p>
            </div>}
          </div>

          {/* Prev / next bar */}
          <div className="mt-3 flex w-full items-center justify-between gap-2 px-4 sm:px-0">
            <button
              onClick={() => prevNumber && goTo(prevNumber)}
              disabled={!prevNumber}
              className={buttonClass("secondary", "sm")}
            >
              <Icon name="skip-prev" size={15} /> {t.prev}
            </button>
            <button onClick={() => setPanelOpen(true)} className={buttonClass("ghost", "sm", "lg:hidden")}>
              <Icon name="list" size={16} /> {t.episodes}
            </button>
            <button
              onClick={() => nextNumber && goTo(nextNumber)}
              disabled={!nextNumber}
              className={buttonClass("secondary", "sm")}
            >
              {t.next} <Icon name="skip-next" size={15} />
            </button>
          </div>
        </div>

        {/* Info + episode panel */}
        <aside className={cn("w-full px-4 sm:px-0", !landscape && "lg:w-[400px] lg:shrink-0")}>
          <EpisodePanel
            wide={landscape}
            drama={drama}
            number={number}
            onSelect={(ep) => goTo(ep.number)}
            autoplay={autoplay}
            onAutoplay={toggleAutoplay}
          />
        </aside>
      </div>

      {/* Mobile episode sheet */}
      <Modal open={panelOpen} onClose={() => setPanelOpen(false)} title={fmt(t.episodesCount, { n: drama.total_episodes })}>
        <EpisodeGrid
          slug={drama.slug}
          episodes={episodes}
          current={number}
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
          <h2 className="mt-4 text-xl font-extrabold">{fmt(t.unlockTitle, { n: number })}</h2>
          <p className="mt-1 text-sm text-text-muted">
            {fmt(t.freeEps, { title: drama.title, n: drama.free_episodes })}
          </p>

          {!user ? (
            <div className="mt-6 space-y-2.5">
              <Button href={`/login?next=${encodeURIComponent(`/drama/${drama.slug}/ep/${number}`)}`} className="w-full" size="lg">
                {t.loginContinue}
              </Button>
              <Button href="/vip" variant="gold" className="w-full" size="lg">
                <Icon name="crown" size={17} /> {t.subscribe}
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
                <Icon name="crown" size={17} /> {t.subscribeAll}
              </Button>
              <Button
                onClick={() => unlock("coins")}
                loading={unlocking === "coins"}
                disabled={!!unlocking || userCoins < coinsRequired}
                variant="primary"
                className="w-full"
                size="lg"
              >
                <Icon name="coin" size={17} /> {fmt(t.unlockCoins, { n: formatNumber(coinsRequired) })}
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
                  <Icon name="layers" size={17} /> {t.usePack}
                </Button>
              )}
              <p className="pt-1 text-xs text-text-dim">
                {t.balance} <span className="font-bold text-primary">{fmt(t.balanceCoins, { n: formatNumber(userCoins) })}</span>
                {userCoins < coinsRequired && (
                  <>
                    {" · "}
                    <Link href="/vip#coins" className="font-semibold text-primary hover:underline">
                      {t.topUpCoins}
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
            {t.notNow}
          </button>
        </div>
      </Modal>
    </div>
  );
}

const STANDARD_HEIGHTS = [144, 240, 360, 480, 720, 1080, 1440, 2160];

/** Bunny encodes e.g. "240p" as 198x352 for 9:16, so name renditions by the nearest standard height. */
function qualityLabel(q: number) {
  const near = STANDARD_HEIGHTS.reduce((best, h) => (Math.abs(h - q) < Math.abs(best - q) ? h : best));
  return `${near}p`;
}

/** Gear menu over the player: Auto + every rendition in the stream. */
function QualityMenu({
  qualities,
  value,
  active,
  onChange,
}: {
  qualities: number[];
  value: number | null;
  active: number | null;
  onChange: (q: number | null) => void;
}) {
  const t = useT().user.watch;
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useDismiss(open, () => setOpen(false), ref);
  const label = qualityLabel;
  const current = value ? label(value) : active ? fmt(t.qualityAutoActive, { q: label(active) }) : t.qualityAuto;
  const options: (number | null)[] = [null, ...qualities];
  return (
    <div ref={ref} className="absolute right-3 top-3 z-20">
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={fmt(t.qualityCurrent, { q: current })}
        title={t.quality}
        className="grid h-10 w-10 place-items-center rounded-full bg-black/50 text-white backdrop-blur transition hover:bg-black/70"
      >
        <Icon name="settings" size={19} />
      </button>
      {open && (
        <div role="menu" className="absolute right-0 top-12 w-44 overflow-hidden rounded-xl border border-white/10 bg-black/85 p-1 text-white shadow-2xl backdrop-blur animate-pop-in">
          <p className="px-3 pb-1 pt-2 text-[11px] font-semibold uppercase tracking-wide text-white/50">{t.quality}</p>
          {options.map((q) => {
            const selected = q === value;
            return (
              <button
                key={q ?? "auto"}
                role="menuitemradio"
                aria-checked={selected}
                onClick={() => {
                  onChange(q);
                  setOpen(false);
                }}
                className="flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition hover:bg-white/10"
              >
                <span>{q ? label(q) : active && !value ? fmt(t.qualityAutoActive, { q: label(active) }) : t.qualityAuto}</span>
                {selected && <Icon name="check" size={16} className="text-primary" />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

function EpisodePanel({
  drama,
  number,
  onSelect,
  autoplay,
  onAutoplay,
  wide,
}: {
  wide?: boolean;
  drama: DramaDetail;
  number: number;
  onSelect: (ep: Episode) => void;
  autoplay: boolean;
  onAutoplay: (v: boolean) => void;
}) {
  const t = useT().user.watch;
  return (
    <div className={cn("space-y-5", wide && "lg:grid lg:grid-cols-[360px_1fr] lg:items-start lg:gap-6 lg:space-y-0")}>
      <div>
        <Link href={`/drama/${drama.slug}`} className="group flex items-start gap-3">
          <div className="relative aspect-[9/16] w-14 shrink-0 overflow-hidden rounded-md bg-surface-2">
            {drama.poster_url && <Image src={drama.poster_url} alt="" fill loading="eager" sizes="56px" className="object-cover" />}
          </div>
          <div className="min-w-0">
            <h1 className="line-clamp-2 text-lg font-bold leading-snug">{drama.title}</h1>
            <p className="mt-1 text-xs text-text-dim">
              {fmt(t.epOf, { n: number, total: drama.total_episodes })} · {fmt(t.views, { n: formatCompact(drama.views) })}
            </p>
          </div>
        </Link>
        <p className="mt-4 line-clamp-4 text-sm leading-relaxed text-text-muted">{drama.synopsis}</p>
        <div className="mt-4 flex items-center justify-between">
          <span className="text-sm font-semibold text-text-muted">{t.autoplay}</span>
          <Toggle checked={autoplay} onChange={onAutoplay} label={t.autoplay} size="sm" />
        </div>
      </div>

      <div className="hidden lg:block">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-bold tracking-tight">{t.episodes}</h2>
          <span className="text-xs text-text-dim">{fmt(t.total, { n: drama.total_episodes })}</span>
        </div>
        <EpisodeGrid key={drama.id} slug={drama.slug} episodes={drama.episodes} current={number} onSelect={onSelect} />
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
