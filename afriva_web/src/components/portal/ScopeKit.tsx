"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { cn, formatCompact, formatDate, shortDate } from "@/lib/format";
import { useT } from "@/lib/i18n";
import { REVIEW_ACTION_LABEL, REVIEW_LABEL, REVIEW_TONE, VIDEO_STATUS_LABEL, VIDEO_STATUS_TONE } from "@/lib/portal";
import type { ContentReview, Drama, ReviewStatus, VideoSource, VideoStatus } from "@/lib/types";
import { EmptyState, Pill, Skeleton } from "../ui/Feedback";
import { Icon, type IconName } from "../ui/Icon";

export function ReviewStatusPill({ status }: { status: ReviewStatus | null | undefined }) {
  const t = useT();
  const s = status ?? "draft";
  return <Pill tone={REVIEW_TONE[s]}>{t(REVIEW_LABEL[s])}</Pill>;
}

export function VideoStatusPill({ status, error }: { status: VideoStatus | null | undefined; error?: string | null }) {
  const t = useT();
  const s = status ?? "ready";
  return (
    <span title={error ?? undefined}>
      <Pill tone={VIDEO_STATUS_TONE[s]}>
        {s === "processing" && <Icon name="refresh" size={11} className="animate-spin" />}
        {t(VIDEO_STATUS_LABEL[s])}
      </Pill>
    </span>
  );
}

/** Live / scheduled / hidden flags for a series. */
export function LiveFlags({ drama }: { drama: Pick<Drama, "is_live" | "is_scheduled" | "publish_at" | "status"> }) {
  const t = useT();
  if (drama.is_live) return <Pill tone="success">{t("Live")}</Pill>;
  if (drama.is_scheduled)
    return (
      <Pill tone="info">
        <Icon name="clock" size={11} /> {t("Scheduled {date}", { date: formatDate(drama.publish_at, true) })}
      </Pill>
    );
  return <Pill>{t("Not published")}</Pill>;
}

/** Coloured info / warning box. */
export function Notice({
  tone = "info",
  icon,
  title,
  children,
  className,
  action,
}: {
  tone?: "info" | "warning" | "danger" | "success";
  icon?: IconName;
  title?: ReactNode;
  children?: ReactNode;
  className?: string;
  action?: ReactNode;
}) {
  const t = useT();
  const tones = {
    info: "border-sky-500/30 bg-sky-500/10 text-sky-200",
    warning: "border-amber-400/30 bg-amber-400/10 text-amber-100",
    danger: "border-danger/30 bg-danger/10 text-red-200",
    success: "border-success/30 bg-success/10 text-green-200",
  };
  const icons: Record<string, IconName> = { info: "info", warning: "alert", danger: "alert", success: "check" };
  return (
    <div className={cn("flex items-start gap-3 rounded-2xl border p-4 text-sm", tones[tone], className)}>
      <Icon name={icon ?? icons[tone]!} size={18} className="mt-0.5 shrink-0" />
      <div className="min-w-0 flex-1">
        {title && <p className="font-bold text-text">{typeof title === "string" ? t(title) : title}</p>}
        {children && <div className={cn(title && "mt-1", "text-text-muted")}>{typeof children === "string" ? t(children) : children}</div>}
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}

/** Shown when the staff role lacks the permission for a page. */
export function NoAccess() {
  return (
    <EmptyState
      icon="shield"
      title="You don't have access to this page"
      description="Your staff role does not include this area. Ask an owner if you need it."
    />
  );
}

/**
 * Video player for review/preview: plays HLS (via hls.js where the browser can't) or MP4,
 * with a quality picker over the provided sources.
 */
export function VideoPreview({
  sources,
  subtitleUrl,
  className,
  onError,
}: {
  sources: VideoSource[];
  subtitleUrl?: string | null;
  className?: string;
  onError?: () => void;
}) {
  const t = useT();
  const ref = useRef<HTMLVideoElement>(null);
  const [idx, setIdx] = useState(0);
  const [failed, setFailed] = useState(false);
  const source = sources[idx] ?? sources[0];

  useEffect(() => {
    const video = ref.current;
    if (!video || !source?.url) return;
    setFailed(false);
    const resumeAt = video.currentTime;
    let destroy: (() => void) | undefined;
    let cancelled = false;
    const resume = () => {
      if (resumeAt > 0) video.currentTime = resumeAt;
    };

    if (source.type === "hls" && !video.canPlayType("application/vnd.apple.mpegurl")) {
      import("hls.js").then(({ default: Hls }) => {
        if (cancelled) return;
        if (!Hls.isSupported()) {
          setFailed(true);
          return;
        }
        const hls = new Hls();
        hls.loadSource(source.url);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, resume);
        hls.on(Hls.Events.ERROR, (_e, data) => {
          if (data.fatal) {
            setFailed(true);
            onError?.();
          }
        });
        destroy = () => hls.destroy();
      });
    } else {
      video.src = source.url;
      video.addEventListener("loadedmetadata", resume, { once: true });
    }
    return () => {
      cancelled = true;
      destroy?.();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [source?.url, source?.type]);

  if (!sources.length || !source?.url) {
    return <div className={cn("grid aspect-[9/16] place-items-center rounded-xl bg-black text-xs text-text-dim", className)}>{t("No video")}</div>;
  }

  return (
    <div className={cn("flex flex-col gap-2", className)}>
      <div className="relative overflow-hidden rounded-xl bg-black">
        <video
          ref={ref}
          controls
          playsInline
          preload="metadata"
          className="aspect-[9/16] max-h-[60vh] w-full bg-black object-contain"
          onError={() => {
            setFailed(true);
            onError?.();
          }}
        >
          {subtitleUrl && <track kind="subtitles" src={subtitleUrl} srcLang="sw" label="Kiswahili" default />}
        </video>
        {failed && (
          <div className="absolute inset-x-2 bottom-12 rounded-lg bg-danger/90 px-3 py-2 text-xs font-semibold text-white">
            {t("This video failed to play.")}
          </div>
        )}
      </div>
      {sources.length > 1 && (
        <div className="flex flex-wrap gap-1" role="radiogroup" aria-label={t("Quality")}>
          {sources.map((s, i) => (
            <button
              key={s.quality + i}
              type="button"
              role="radio"
              aria-checked={i === idx}
              onClick={() => setIdx(i)}
              className={cn(
                "rounded-full px-2.5 py-1 text-[11px] font-semibold transition",
                i === idx ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:text-text",
              )}
            >
              {s.quality === "auto" ? t("Auto") : s.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** Review history with reviewer notes. */
export function ReviewTimeline({ reviews, empty = "No review activity yet" }: { reviews: ContentReview[]; empty?: string }) {
  const t = useT();
  if (!reviews.length) return <p className="text-sm text-text-dim">{t(empty)}</p>;
  return (
    <ol className="relative space-y-4 border-l border-border pl-5">
      {reviews.map((r) => (
        <li key={r.id} className="relative">
          <span
            className={cn(
              "absolute -left-[26px] top-1 h-3 w-3 rounded-full border-2 border-bg",
              r.action === "approve" || r.action === "published"
                ? "bg-success"
                : r.action === "reject"
                  ? "bg-danger"
                  : r.action === "request_changes"
                    ? "bg-primary"
                    : "bg-text-dim",
            )}
          />
          <p className="text-sm font-semibold">
            {t(REVIEW_ACTION_LABEL[r.action] ?? r.action)}
            {r.episode_number ? <span className="text-text-dim"> · {t("Episode {n}", { n: r.episode_number })}</span> : null}
          </p>
          <p className="text-xs text-text-dim">
            {formatDate(r.created_at, true)}
            {r.user?.name ? ` · ${r.user.name}` : ""}
          </p>
          {r.notes && <p className="mt-1.5 whitespace-pre-line rounded-xl bg-surface-2 px-3 py-2 text-sm text-text-muted">{r.notes}</p>}
        </li>
      ))}
    </ol>
  );
}

export const RANGES = [7, 30, 90, 365] as const;

export function RangeSelect({ value, onChange, options = RANGES }: { value: number; onChange: (d: number) => void; options?: readonly number[] }) {
  const t = useT();
  return (
    <div role="radiogroup" aria-label={t("Period")} className="flex rounded-full bg-surface-2 p-1">
      {options.map((d) => (
        <button
          key={d}
          role="radio"
          aria-checked={value === d}
          onClick={() => onChange(d)}
          className={cn(
            "rounded-full px-3 py-1.5 text-xs font-semibold transition",
            value === d ? "bg-primary text-white" : "text-text-muted hover:text-text",
          )}
        >
          {d === 365 ? t("12 months") : t("{n} days", { n: d })}
        </button>
      ))}
    </div>
  );
}

const AXIS = { fill: "#737373", fontSize: 11 };
const GRID = "#1F1F1F";

/** Two measures on one time axis (e.g. gross vs net, bought vs spent). */
export function DualTrendChart<T extends { date: string }>({
  data,
  series,
  loading,
  height = 260,
  format = (v: number) => formatCompact(v),
}: {
  data: T[];
  series: { key: keyof T & string; label: string; color: string }[];
  loading?: boolean;
  height?: number;
  format?: (v: number) => string;
}) {
  const t = useT();
  if (loading) return <div style={{ height }} className="skeleton w-full rounded-xl" />;
  const empty = !data.length || data.every((d) => series.every((s) => !Number(d[s.key])));
  if (empty) return <EmptyState icon="chart" title="No data for this period" className="py-10" />;
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
          <CartesianGrid stroke={GRID} vertical={false} />
          <XAxis dataKey="date" tick={AXIS} tickLine={false} axisLine={false} tickFormatter={shortDate} minTickGap={24} />
          <YAxis tick={AXIS} tickLine={false} axisLine={false} tickFormatter={(v) => formatCompact(v)} width={48} />
          <Tooltip
            contentStyle={{ background: "#1A1A1A", border: "1px solid #262626", borderRadius: 12, fontSize: 12 }}
            labelFormatter={(l) => shortDate(String(l))}
            formatter={(v) => format(Number(v))}
          />
          <Legend wrapperStyle={{ fontSize: 12 }} />
          {series.map((s) => (
            <Line key={s.key} type="monotone" dataKey={s.key} name={t(s.label)} stroke={s.color} strokeWidth={2} dot={false} />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

/** Where unfinished playbacks stopped, in tenths of the episode. */
export function DropOffChart({ data, loading }: { data: { from_percent: number; to_percent: number; sessions: number }[]; loading?: boolean }) {
  const t = useT();
  if (loading) return <Skeleton className="h-[220px] w-full rounded-xl" />;
  if (!data.some((d) => d.sessions > 0)) return <EmptyState icon="chart" title="No data for this period" className="py-10" />;
  const rows = data.map((d) => ({ label: `${d.from_percent}–${d.to_percent}%`, value: d.sessions }));
  return (
    <div style={{ height: 220 }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={rows} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
          <CartesianGrid stroke={GRID} vertical={false} />
          <XAxis dataKey="label" tick={AXIS} tickLine={false} axisLine={false} />
          <YAxis tick={AXIS} tickLine={false} axisLine={false} width={40} allowDecimals={false} />
          <Tooltip
            cursor={{ fill: "rgba(255,255,255,0.04)" }}
            contentStyle={{ background: "#1A1A1A", border: "1px solid #262626", borderRadius: 12, fontSize: 12 }}
            formatter={(v) => [String(v), t("Viewers who stopped here")]}
          />
          <Bar dataKey="value" fill="#E1122B" radius={[4, 4, 0, 0]} maxBarSize={36} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
