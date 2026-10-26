"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { sendPlayerEvents } from "@/lib/analytics";
import { ApiError, api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatCompact, formatNumber } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { DramaDetail, Episode, PlayData, PlayerEventType, UnlockInfo, VideoSource } from "@/lib/types";
import { Button, buttonClass } from "../ui/Button";
import { ApiDownState, EmptyState, Spinner } from "../ui/Feedback";
import { Toggle } from "../ui/Form";
import { Icon } from "../ui/Icon";
import { Modal } from "../ui/Modal";
import { EpisodeGrid } from "./EpisodeGrid";
import { SourceVideo } from "./VideoSource";

type PlayState =
  | { kind: "loading" }
  | { kind: "ready"; play: PlayData }
  | { kind: "locked"; message: string; unlock: UnlockInfo | null }
  | { kind: "error"; message: string };

const AUTOPLAY_KEY = "afriva_autoplay";
const PROGRESS_EVERY = 10; // seconds of playback between progress saves
const HEARTBEAT_MS = 15_000;

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
  const t = useT();
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
  const [quality, setQuality] = useState("auto");
  const [qualityOpen, setQualityOpen] = useState(false);
  const [startAt, setStartAt] = useState(0);
  const [attempt, setAttempt] = useState(0);
  const [playbackError, setPlaybackError] = useState(false);
  // Analytics (SPEC §8.3): watch time accumulated since the last event of this playback session.
  const analytics = useRef({ started: false, watched: 0, lastTime: 0, flushed: false });
  const flushRef = useRef<(() => void) | null>(null);

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
        analytics.current = { started: false, watched: 0, lastTime: play.resume_seconds ?? 0, flushed: false };
        setStartAt(play.resume_seconds ?? 0);
        setPlaybackError(false);
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
  }, [episodeId, user?.id, attempt]);

  const goTo = useCallback(
    (n: number) => {
      if (!drama || n === number) return;
      flushRef.current?.();
      setState({ kind: "loading" });
      setNumber(n);
      setQuality("auto");
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
      if (!user || !episodeId) return;
      // The <video> may already be unmounted when leaving an episode; fall back to the last known time.
      const secs = Math.floor(videoRef.current?.currentTime ?? analytics.current.lastTime);
      if (secs <= 0 && !force) return;
      if (!force && Math.abs(secs - lastSaved.current) < PROGRESS_EVERY) return;
      if (force && secs === lastSaved.current) return;
      lastSaved.current = secs;
      api.post(`/episodes/${episodeId}/progress`, { progress_seconds: secs }).catch(() => {});
    },
    [user, episodeId],
  );

  const sessionId = play?.session_id ?? null;
  const track = useCallback(
    (type: PlayerEventType, extra: { quality?: string; error_code?: string } = {}) => {
      const v = videoRef.current;
      if (!sessionId || !episodeId) return;
      const a = analytics.current;
      const watched = Math.min(120, Math.round(a.watched));
      a.watched -= watched;
      sendPlayerEvents([
        {
          session_id: sessionId,
          episode_id: episodeId,
          type,
          position_seconds: Math.floor(v?.currentTime ?? a.lastTime),
          watched_seconds: watched,
          duration_seconds: v && Number.isFinite(v.duration) ? Math.floor(v.duration) : undefined,
          ...extra,
        },
      ]);
    },
    [sessionId, episodeId],
  );

  // Lets goTo() flush the current episode before switching (goTo is declared before these callbacks).
  useEffect(() => {
    flushRef.current = () => {
      if (analytics.current.flushed) return;
      analytics.current.flushed = true;
      saveProgress(true);
      if (analytics.current.watched > 0) track("pause");
    };
  }, [saveProgress, track]);

  // Heartbeat while playing; flush progress + a pause event when leaving the episode or the page.
  useEffect(() => {
    if (!sessionId) return;
    const beat = setInterval(() => {
      const v = videoRef.current;
      if (v && !v.paused && analytics.current.started) track("heartbeat");
    }, HEARTBEAT_MS);
    const onHide = () => {
      if (document.visibilityState === "hidden") {
        saveProgress(true);
        if (analytics.current.watched > 0) track("pause");
      }
    };
    document.addEventListener("visibilitychange", onHide);
    window.addEventListener("pagehide", onHide);
    return () => {
      clearInterval(beat);
      document.removeEventListener("visibilitychange", onHide);
      window.removeEventListener("pagehide", onHide);
      // Leaving the page or episode (goTo() may already have flushed).
      if (!analytics.current.flushed) {
        analytics.current.flushed = true;
        saveProgress(true);
        if (analytics.current.watched > 0) track("pause");
      }
    };
  }, [sessionId, track, saveProgress]);

  const onTimeUpdate = () => {
    const v = videoRef.current;
    if (!v) return;
    const a = analytics.current;
    const delta = v.currentTime - a.lastTime;
    if (!v.paused && delta > 0 && delta < 2) a.watched += delta;
    a.lastTime = v.currentTime;
    saveProgress();
  };

  const onPlaying = () => {
    setPlaybackError(false);
    if (!analytics.current.started) {
      analytics.current.started = true;
      track("start");
    }
  };

  const onPause = () => {
    const v = videoRef.current;
    if (v?.ended) return;
    saveProgress(true);
    track("pause");
  };

  const onEnded = () => {
    saveProgress(true);
    track("complete");
    if (autoplay && nextNumber) goTo(nextNumber);
  };

  const onPlaybackError = (code: string) => {
    setPlaybackError(true);
    track("error", { error_code: code.slice(0, 60) });
  };

  const retryPlayback = () => {
    setStartAt(Math.floor(videoRef.current?.currentTime || analytics.current.lastTime || 0));
    setPlaybackError(false);
    setAttempt((n) => n + 1);
  };

  const sources: VideoSource[] = play
    ? play.sources?.length
      ? play.sources
      : [{ quality: "auto", label: "Auto", url: play.video_url, type: play.video_url.split("?")[0]!.endsWith(".m3u8") ? "hls" : "mp4" }]
    : [];
  const source = sources.find((x) => x.quality === quality) ?? sources[0] ?? null;

  const pickQuality = (q: string) => {
    setQualityOpen(false);
    if (q === source?.quality) return;
    setStartAt(Math.floor(videoRef.current?.currentTime ?? 0));
    setQuality(q);
    track("quality", { quality: q });
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
      toast.success(t("Episode {n} unlocked", { n: number }));
      setDrama((d) =>
        d ? { ...d, episodes: d.episodes.map((e) => (e.id === episodeId ? { ...e, is_unlocked: true } : e)) } : d,
      );
      if (method === "coins" && state.kind === "locked" && state.unlock) {
        const spent = state.unlock.coins_required;
        setUser((u) => (u ? { ...u, coins: Math.max(0, u.coins - spent) } : u));
      }
      refresh();
      const playData = await api.get<PlayData>(`/episodes/${episodeId}/play`);
      analytics.current = { started: false, watched: 0, lastTime: playData.resume_seconds ?? 0, flushed: false };
      setStartAt(playData.resume_seconds ?? 0);
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
            title={t("This drama isn't available")}
            description={t("It may have been removed or the link is wrong.")}
            action={<Button href="/browse">{t("Browse dramas")}</Button>}
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
          title={t("Episode {n} isn't out yet", { n: number })}
          description={t("New episodes drop regularly. Start from the beginning or pick another.")}
          action={<Button href={`/drama/${drama.slug}`}>{t("Back to {title}", { title: drama.title })}</Button>}
        />
      </div>
    );
  }

  const unlockInfo = state.kind === "locked" ? state.unlock : null;
  const coinsRequired = unlockInfo?.coins_required ?? drama.coins_per_episode;
  const userCoins = user ? (unlockInfo?.user_coins ?? user.coins) : 0;
  const vipOnly = unlockInfo?.vip_only ?? episode.vip_only ?? drama.access_mode === "vip_only";
  const canUseVip = unlockInfo?.can_use_vip ?? drama.access_mode !== "coins_only";
  const canUseCoins = !vipOnly && (unlockInfo?.can_use_coins ?? true);

  return (
    <div className="relative">
      <div className="mx-auto flex max-w-[1280px] flex-col gap-6 px-0 pb-6 sm:px-6 sm:pt-6 lg:flex-row lg:items-start lg:justify-center lg:gap-8 lg:px-8">
        {/* Player column */}
        <div className="flex flex-col items-center lg:sticky lg:top-[112px]">
          <div
            className="chrome-dark relative aspect-[9/16] w-full overflow-hidden bg-black sm:w-auto sm:rounded-2xl sm:ring-1 sm:ring-white/10"
            style={{ height: "min(calc(100dvh - 9rem), 860px)", maxWidth: "100%" }}
          >
            {state.kind === "ready" && source ? (
              <>
                <SourceVideo
                  key={`${state.play.session_id}-${source.quality}-${attempt}`}
                  ref={videoRef}
                  source={source}
                  startAt={startAt}
                  onFatalError={onPlaybackError}
                  poster={episode.thumbnail_url ?? undefined}
                  className="h-full w-full bg-black object-contain"
                  controls
                  autoPlay
                  playsInline
                  controlsList="nodownload"
                  crossOrigin={state.play.subtitle_url ? "anonymous" : undefined}
                  onTimeUpdate={onTimeUpdate}
                  onPlaying={onPlaying}
                  onPause={onPause}
                  onEnded={onEnded}
                  onError={() => onPlaybackError("media_error")}
                >
                  {state.play.subtitle_url && (
                    <track kind="subtitles" src={state.play.subtitle_url} srcLang="sw" label="Kiswahili" default />
                  )}
                </SourceVideo>
                {playbackError && (
                  <div className="absolute inset-0 grid place-items-center bg-black/70">
                    <div className="flex flex-col items-center gap-3 px-6 text-center">
                      <Icon name="alert" size={32} className="text-danger" />
                      <p className="text-sm text-text-muted">{t("The video couldn't play. Check your connection and try again.")}</p>
                      <Button onClick={retryPlayback}>
                        <Icon name="refresh" size={16} /> {t("Try again")}
                      </Button>
                    </div>
                  </div>
                )}
                {sources.length > 1 && (
                  <div className="absolute right-3 top-14 z-10">
                    <button
                      onClick={() => setQualityOpen((o) => !o)}
                      aria-haspopup="listbox"
                      aria-expanded={qualityOpen}
                      aria-label={t("Video quality")}
                      className="flex items-center gap-1 rounded-full bg-black/60 px-3 py-1.5 text-xs font-bold text-white ring-1 ring-white/20 hover:bg-black/80"
                    >
                      <Icon name="settings" size={14} /> {source.quality === "auto" ? t("Auto") : source.label}
                    </button>
                    {qualityOpen && (
                      <ul role="listbox" aria-label={t("Video quality")} className="absolute right-0 mt-1 w-32 overflow-hidden rounded-xl border border-white/15 bg-black/90 p-1">
                        {sources.map((q) => (
                          <li key={q.quality}>
                            <button
                              role="option"
                              aria-selected={q.quality === source.quality}
                              onClick={() => pickQuality(q.quality)}
                              className="flex w-full items-center justify-between rounded-lg px-3 py-1.5 text-left text-xs font-semibold text-white/80 hover:bg-white/10 hover:text-white"
                            >
                              {q.quality === "auto" ? t("Auto") : q.label}
                              {q.quality === source.quality && <Icon name="check" size={13} className="text-primary" />}
                            </button>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                )}
              </>
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
                      <p className="text-lg font-bold">{t("Episode {n} is locked", { n: number })}</p>
                      <Button onClick={() => setPaywallOpen(true)}>{t("Unlock to keep watching")}</Button>
                    </div>
                  )}
                  {state.kind === "error" && (
                    <div className="flex flex-col items-center gap-3 px-6 text-center">
                      <Icon name="alert" size={32} className="text-danger" />
                      <p className="text-sm text-text-muted">{state.message}</p>
                      <Button
                        variant="secondary"
                        onClick={() => {
                          setState({ kind: "loading" });
                          setAttempt((n) => n + 1);
                        }}
                      >
                        <Icon name="refresh" size={16} /> {t("Try again")}
                      </Button>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Episode label */}
            <div className="pointer-events-none absolute left-0 right-0 top-0 bg-gradient-to-b from-black/70 to-transparent p-4">
              <p className="truncate text-sm font-bold">{drama.title}</p>
              <p className="text-xs text-white/70">
                {t("EP {n}", { n: number })}
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
              <Icon name="skip-prev" size={15} /> {t("Prev")}
            </button>
            <button onClick={() => setPanelOpen(true)} className={buttonClass("ghost", "sm", "lg:hidden")}>
              <Icon name="list" size={16} /> {t("Episodes")}
            </button>
            <button
              onClick={() => nextNumber && goTo(nextNumber)}
              disabled={!nextNumber}
              className={buttonClass("secondary", "sm")}
            >
              {t("Next")} <Icon name="skip-next" size={15} />
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
      <Modal open={panelOpen} onClose={() => setPanelOpen(false)} title={t("Episodes · {n}", { n: drama.total_episodes })}>
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
          <h2 className="mt-4 text-xl font-extrabold">{t("Unlock Episode {n}", { n: number })}</h2>
          <p className="mt-1 text-sm text-text-muted">
            {drama.title}: {t("EP 1–{n} are free. Keep the story going:", { n: drama.free_episodes })}
          </p>
          {state.kind === "locked" && state.message && <p className="mt-2 text-xs text-text-dim">{state.message}</p>}

          {!user || unlockInfo?.requires_login ? (
            <div className="mt-6 space-y-2.5">
              <Button href={`/login?next=${encodeURIComponent(`/drama/${drama.slug}/ep/${number}`)}`} className="w-full" size="lg">
                {t("Log in to continue")}
              </Button>
              {canUseVip && (
                <Button href="/vip" variant="gold" className="w-full" size="lg">
                  <Icon name="crown" size={17} /> {t("Subscribe VIP")}
                </Button>
              )}
            </div>
          ) : (
            <div className="mt-6 space-y-2.5">
              {vipOnly && <p className="rounded-xl bg-surface-2 p-3 text-sm text-text-muted">{t("This series is for VIP members only.")}</p>}
              {canUseVip && (
                <Button
                  href={`/vip?next=${encodeURIComponent(`/drama/${drama.slug}/ep/${number}`)}`}
                  variant="gold"
                  className="w-full"
                  size="lg"
                >
                  <Icon name="crown" size={17} /> {t("Subscribe VIP: watch everything")}
                </Button>
              )}
              {canUseCoins && (
                <Button
                  onClick={() => unlock("coins")}
                  loading={unlocking === "coins"}
                  disabled={!!unlocking || userCoins < coinsRequired}
                  variant="primary"
                  className="w-full"
                  size="lg"
                >
                  <Icon name="coin" size={17} /> {t("Unlock for {n} coins", { n: formatNumber(coinsRequired) })}
                </Button>
              )}
              {canUseCoins && unlockInfo?.can_use_pack && (
                <Button
                  onClick={() => unlock("episode_pack")}
                  loading={unlocking === "episode_pack"}
                  disabled={!!unlocking}
                  variant="secondary"
                  className="w-full"
                  size="lg"
                >
                  <Icon name="layers" size={17} /> {t("Use my episode pack")}
                </Button>
              )}
              {canUseCoins && (
              <p className="pt-1 text-xs text-text-dim">
                {t("Your balance:")}{" "}
                <span className="font-bold text-primary">{t("{n} coins", { n: formatNumber(userCoins) })}</span>
                {userCoins < coinsRequired && (
                  <>
                    {" · "}
                    <Link href="/vip#coins" className="font-semibold text-primary hover:underline">
                      {t("Top up coins")}
                    </Link>
                  </>
                )}
              </p>
              )}
            </div>
          )}
          <button
            onClick={() => setPaywallOpen(false)}
            className="mt-4 text-sm font-semibold text-text-dim transition hover:text-text"
          >
            {t("Not now")}
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
  const t = useT();
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
              {t("EP {n} / {total}", { n: number, total: drama.total_episodes })} ·{" "}
              {t("{n} views", { n: formatCompact(drama.views) })}
            </p>
          </div>
        </Link>
        <p className="mt-4 line-clamp-4 text-sm leading-relaxed text-text-muted">{drama.synopsis}</p>
        <div className="mt-4 flex items-center justify-between border-t border-border pt-4">
          <span className="text-sm font-semibold text-text-muted">{t("Autoplay next episode")}</span>
          <Toggle checked={autoplay} onChange={onAutoplay} label="Autoplay next episode" size="sm" />
        </div>
      </div>

      <div className="hidden rounded-2xl border border-border bg-surface p-5 lg:block">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-bold">{t("Episodes")}</h2>
          <span className="text-xs text-text-dim">{t("{n} total", { n: drama.total_episodes })}</span>
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
