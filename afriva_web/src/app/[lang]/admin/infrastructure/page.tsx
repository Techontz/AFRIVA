"use client";

import { useState, type ReactNode } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { Card, PageHeader, StatCard } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill, Skeleton, type Tone } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { useLocale, useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { cn, formatDate, formatNumber } from "@/lib/format";
import { useApi } from "@/lib/hooks";

type CostTag = "live_usage" | "estimate" | "billed";

interface Section<D> {
  key: string;
  source: string;
  configured: boolean;
  ok: boolean;
  as_of: string | null;
  env?: string[];
  error?: string;
  data: D | null;
}

interface ServerData {
  load: number[] | null;
  cpu_cores: number | null;
  load_percent: number | null;
  memory_total_bytes: number | null;
  memory_available_bytes: number | null;
  memory_used_percent: number | null;
  disk_total_bytes: number | null;
  disk_free_bytes: number | null;
  disk_used_percent: number | null;
  php_version: string;
}

interface DatabaseData {
  driver: string;
  size_bytes: number | null;
  tables: number | null;
  redis: { in_use: boolean; ok?: boolean; used_memory_bytes?: number | null; max_memory_bytes?: number | null };
}

interface AppData {
  episodes_with_video: number;
  episodes_processing: number;
  episodes_failed: number;
  episodes_stuck: number;
  samples_failed: number;
  samples_processing: number;
  failed_jobs: number | null;
}

interface HetznerData {
  name: string | null;
  status: string | null;
  server_type: string | null;
  cores: number | null;
  memory_gb: number | null;
  disk_gb: number | null;
  location: string | null;
  backups_enabled: boolean;
  backup_percent: number;
  price_monthly_gross_eur: number | null;
}

interface BunnyData {
  account_connected: boolean;
  video_count: number;
  storage_bytes: number;
  bandwidth_month_bytes?: number | null;
  requests_month?: number | null;
  cache_hit_rate?: number | null;
  billing?: { this_month_charges: number | null; balance: number | null };
  partial_errors?: Record<string, string>;
}

interface R2Data {
  storage_bytes: number;
  object_count: number;
  buckets: { name: string; storage_bytes: number; object_count: number }[];
  class_a_month: number | null;
  class_b_month: number | null;
  partial_errors?: Record<string, string>;
}

interface CostLine {
  provider: string;
  label: string;
  amount_usd: number | null;
  tag: CostTag;
  basis: string;
  billed_to_date_usd?: number;
}

interface Snapshot {
  generated_at: string;
  cache_ttl_seconds: number;
  sections: {
    server: Section<ServerData>;
    database: Section<DatabaseData>;
    app: Section<AppData>;
    hetzner: Section<HetznerData>;
    bunny: Section<BunnyData>;
    r2: Section<R2Data>;
  };
  cost: { currency: string; total_usd: number; complete: boolean; lines: CostLine[] };
  budget: {
    monthly_budget_usd: number | null;
    estimated_total_usd: number;
    percent: number | null;
    thresholds: { percent: number; reached: boolean; alert_sent: boolean }[];
    alert_email_configured: boolean;
  };
}

const TAG_TONE: Record<CostTag, Tone> = { live_usage: "success", estimate: "info", billed: "brand" };

function usd(n: number | null | undefined): string {
  if (n === null || n === undefined) return "-";
  return `US$ ${Number(n).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function bytes(n: number | null | undefined): string {
  if (n === null || n === undefined) return "-";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let v = Number(n);
  let i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return `${v.toLocaleString("en-US", { maximumFractionDigits: v >= 100 || i === 0 ? 0 : 1 })} ${units[i]}`;
}

function TagPill({ tag }: { tag: CostTag }) {
  const t = useT().admin.infrastructure.legend;
  return <Pill tone={TAG_TONE[tag]}>{t[tag]}</Pill>;
}

function Meter({ percent }: { percent: number | null | undefined }) {
  const p = Math.max(0, Math.min(100, Number(percent ?? 0)));
  return (
    <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-surface-3" aria-hidden="true">
      <div className={cn("h-full rounded-full", p >= 90 ? "bg-danger" : "bg-primary")} style={{ width: `${p}%` }} />
    </div>
  );
}

function Row({ label, value, hint }: { label: ReactNode; value: ReactNode; hint?: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-border py-2.5 text-sm last:border-b-0">
      <div className="min-w-0">
        <p className="text-text-muted">{label}</p>
        {hint && <p className="mt-0.5 text-xs text-text-dim">{hint}</p>}
      </div>
      <div className="shrink-0 text-right font-semibold tabular-nums">{value}</div>
    </div>
  );
}

/** Wraps a provider card: "Not connected" (with the env variables to set), an error note, or the content. */
function SectionCard<D>({
  title,
  icon,
  section,
  loading,
  tag,
  children,
}: {
  title: string;
  icon: Parameters<typeof Icon>[0]["name"];
  section: Section<D> | undefined;
  loading: boolean;
  tag?: CostTag;
  children: (data: D) => ReactNode;
}) {
  const tr = useT().admin.infrastructure;
  const locale = useLocale();
  const header = (
    <div className="flex items-center gap-2">
      <span className="grid h-8 w-8 place-items-center rounded-lg bg-primary/15 text-primary">
        <Icon name={icon} size={16} />
      </span>
      <span>{title}</span>
    </div>
  );

  let body: ReactNode;
  if (loading || !section) {
    body = (
      <div className="flex flex-col gap-3">
        <Skeleton className="h-5 w-3/4" />
        <Skeleton className="h-5 w-1/2" />
        <Skeleton className="h-5 w-2/3" />
      </div>
    );
  } else if (!section.configured) {
    body = (
      <div className="rounded-xl border border-dashed border-border p-4 text-sm">
        <Pill tone="neutral">{tr.notConnected}</Pill>
        <p className="mt-3 text-text-muted">{tr.notConnectedHint}</p>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {(section.env ?? []).map((v) => (
            <code key={v} className="rounded-md bg-surface-2 px-2 py-1 text-xs text-text">
              {v}
            </code>
          ))}
        </div>
      </div>
    );
  } else if (!section.ok || !section.data) {
    body = (
      <p className="flex items-start gap-2 rounded-xl bg-danger/10 p-3 text-sm text-danger">
        <Icon name="alert" size={16} className="mt-0.5 shrink-0" />
        {fmt(tr.unavailable, { error: section.error ?? "-" })}
      </p>
    );
  } else {
    body = children(section.data);
  }

  return (
    <Card title={header} actions={section?.configured && section.ok && tag ? <TagPill tag={tag} /> : undefined}>
      {body}
      {section?.configured && section.as_of && (
        <p className="mt-3 text-xs text-text-dim">
          {fmt(tr.sourceAsOf, {
            source: tr.sources[section.key as keyof typeof tr.sources] ?? section.source,
            time: formatDate(section.as_of, true, locale),
          })}
        </p>
      )}
    </Card>
  );
}

function PartialNote({ errors }: { errors?: Record<string, string> }) {
  const tr = useT().admin.infrastructure;
  if (!errors || Object.keys(errors).length === 0) return null;
  const parts = Object.entries(errors)
    .map(([k, v]) => `${k} (${v})`)
    .join(", ");
  return <p className="mt-3 rounded-lg bg-surface-2 p-2.5 text-xs text-text-muted">{fmt(tr.partial, { parts })}</p>;
}

function BudgetBar({ budget }: { budget: Snapshot["budget"] }) {
  const tr = useT().admin.infrastructure.budget;
  const percent = budget.percent ?? 0;
  const fill = Math.min(100, percent);
  return (
    <div>
      <p className="text-sm font-semibold">
        {fmt(tr.used, { percent: Math.round(percent * 10) / 10, budget: usd(budget.monthly_budget_usd) })}
      </p>
      {/* Marker labels alternate below and above the bar so 90% and 100% never overlap on narrow cards. */}
      <div className="relative mt-2 pb-6 pt-5">
        <div
          className="h-3 overflow-hidden rounded-full bg-surface-3"
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(fill)}
          aria-label={tr.title}
        >
          <div
            className={cn("h-full rounded-full transition-[width]", percent >= 100 ? "bg-danger" : "bg-primary")}
            style={{ width: `${fill}%` }}
          />
        </div>
        {budget.thresholds.map((th, i) => {
          const above = i % 2 === 1;
          return (
            <div key={th.percent} className="absolute top-5" style={{ left: `${Math.min(th.percent, 100)}%` }}>
              <span className={cn("absolute top-0 h-3 w-0.5 -translate-x-1/2", th.reached ? "bg-text" : "bg-text-dim")} />
              <span
                className={cn(
                  "absolute whitespace-nowrap text-[11px] tabular-nums",
                  above ? "-top-5" : "top-4",
                  th.percent >= 100 ? "right-0 translate-x-[1px]" : "-translate-x-1/2",
                  th.reached ? "font-bold text-text" : "text-text-dim",
                )}
                title={th.alert_sent ? tr.alertSent : undefined}
              >
                {fmt(tr.marker, { percent: th.percent })}
                {th.alert_sent ? " \u2713" : ""}
              </span>
            </div>
          );
        })}
      </div>
      <p className="text-xs text-text-muted">{budget.alert_email_configured ? tr.alertsInfo : tr.noEmail}</p>
    </div>
  );
}

export default function InfrastructurePage() {
  const { admin } = useT();
  const tr = admin.infrastructure;
  const locale = useLocale();
  const { data, loading, error, reload, mutate } = useApi<Snapshot>("/admin/infrastructure");
  const [refreshing, setRefreshing] = useState(false);

  const refresh = async () => {
    setRefreshing(true);
    try {
      const fresh = await api.get<Snapshot>("/admin/infrastructure", { refresh: 1 });
      mutate(() => fresh);
      toast.success(tr.refreshed);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setRefreshing(false);
    }
  };

  const header = (
    <PageHeader
      title={admin.nav.infrastructure}
      description={tr.description}
      actions={
        <Button variant="outline" size="sm" onClick={() => void refresh()} loading={refreshing} disabled={loading}>
          {!refreshing && <Icon name="refresh" size={15} />}
          {tr.refresh}
        </Button>
      }
    />
  );

  if (error && !data) {
    return (
      <>
        {header}
        <LoadError onRetry={reload} />
      </>
    );
  }

  const s = data?.sections;
  const cost = data?.cost;
  const budget = data?.budget;
  const busy = loading && !data;

  return (
    <>
      {header}

      {data && (
        <p className="-mt-3 mb-5 text-xs text-text-dim">
          {fmt(tr.generated, {
            time: formatDate(data.generated_at, true, locale),
            minutes: Math.round(data.cache_ttl_seconds / 60),
          })}
        </p>
      )}

      <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
        <StatCard loading={busy} label={tr.cost.total} icon="wallet" value={usd(cost?.total_usd)} hint={tr.legend.estimate} />
        <StatCard
          loading={busy}
          label={tr.budget.title}
          icon="chart"
          accent={budget?.percent !== null && (budget?.percent ?? 0) >= 90 ? "brand" : "success"}
          value={budget?.monthly_budget_usd ? `${Math.round((budget.percent ?? 0) * 10) / 10}%` : "-"}
          hint={budget?.monthly_budget_usd ? usd(budget.monthly_budget_usd) : tr.budget.setBudget}
        />
        <StatCard
          loading={busy}
          label={tr.video.videos}
          icon="film"
          accent="info"
          value={s?.bunny.ok && s.bunny.data ? formatNumber(s.bunny.data.video_count) : "-"}
          hint={s?.bunny.configured ? tr.legend.live_usage : tr.notConnected}
        />
        <StatCard
          loading={busy}
          label={tr.storage.total}
          icon="layers"
          accent="info"
          value={s?.r2.ok && s.r2.data ? bytes(s.r2.data.storage_bytes) : "-"}
          hint={s?.r2.configured ? tr.legend.live_usage : tr.notConnected}
        />
      </div>

      <Card title={tr.legend.title} className="mt-4">
        <div className="grid gap-3 sm:grid-cols-3">
          {(["live_usage", "estimate", "billed"] as const).map((tag) => (
            <div key={tag} className="flex flex-col items-start gap-1.5 text-sm">
              <TagPill tag={tag} />
              <p className="text-text-muted">{tr.legend[`${tag}Hint`]}</p>
            </div>
          ))}
        </div>
      </Card>

      <div className="mt-4 grid gap-4 xl:grid-cols-3">
        <Card title={tr.cost.title} className="xl:col-span-2">
          {busy || !cost ? (
            <div className="flex flex-col gap-3">
              {[0, 1, 2, 3].map((i) => (
                <Skeleton key={i} className="h-6" />
              ))}
            </div>
          ) : (
            <>
              <div className="-mx-1 overflow-x-auto">
                <table className="w-full min-w-[440px] text-sm">
                  <thead>
                    <tr className="text-left text-xs uppercase tracking-wider text-text-dim">
                      <th className="px-1 pb-2 font-semibold">{tr.cost.provider}</th>
                      <th className="px-1 pb-2 font-semibold">{tr.cost.type}</th>
                      <th className="px-1 pb-2 text-right font-semibold">{tr.cost.amount}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {cost.lines.map((line) => (
                      <tr key={line.provider} className="border-t border-border align-top">
                        <td className="px-1 py-2.5">
                          <p className="font-semibold">{tr.cost.labels[line.provider as keyof typeof tr.cost.labels] ?? line.label}</p>
                          <p className="text-xs text-text-dim">
                            {tr.cost.basis[line.basis as keyof typeof tr.cost.basis] ?? line.basis}
                          </p>
                        </td>
                        <td className="px-1 py-2.5">
                          <div className="flex flex-wrap gap-1">
                            {line.amount_usd !== null && <TagPill tag={line.tag} />}
                            {line.billed_to_date_usd !== undefined && <TagPill tag="billed" />}
                          </div>
                        </td>
                        <td className="px-1 py-2.5 text-right tabular-nums">
                          <p className="font-semibold">{line.amount_usd === null ? tr.notConnected : usd(line.amount_usd)}</p>
                          {line.billed_to_date_usd !== undefined && (
                            <p className="text-xs text-text-dim">{fmt(tr.cost.billedToDate, { amount: usd(line.billed_to_date_usd) })}</p>
                          )}
                        </td>
                      </tr>
                    ))}
                    <tr className="border-t-2 border-border">
                      <td className="px-1 pt-3 font-bold" colSpan={2}>
                        {tr.cost.total}
                      </td>
                      <td className="px-1 pt-3 text-right text-base font-extrabold tabular-nums">{usd(cost.total_usd)}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              {!cost.complete && <p className="mt-3 text-xs text-text-muted">{tr.cost.incomplete}</p>}
            </>
          )}
        </Card>

        <Card title={tr.budget.title}>
          {busy || !budget ? (
            <Skeleton className="h-16" />
          ) : budget.monthly_budget_usd ? (
            <BudgetBar budget={budget} />
          ) : (
            <div className="flex flex-col items-start gap-3 text-sm text-text-muted">
              <p>{tr.budget.none}</p>
              <Button href="/admin/settings" size="sm" variant="outline">
                {tr.budget.setBudget}
              </Button>
            </div>
          )}
        </Card>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        <SectionCard title={tr.server.title} icon="server" section={s?.server} loading={busy} tag="live_usage">
          {(d) => (
            <>
              <Row
                label={tr.server.load}
                hint={tr.server.loadDetail}
                value={
                  d.load ? (
                    <>
                      {d.load.join(" / ")}
                      {d.cpu_cores ? <p className="text-xs font-normal text-text-dim">{fmt(tr.server.cores, { n: d.cpu_cores })}</p> : null}
                    </>
                  ) : (
                    tr.na
                  )
                }
              />
              <div className="border-b border-border py-2.5 text-sm">
                <div className="flex justify-between gap-4">
                  <span className="text-text-muted">{tr.server.memory}</span>
                  <span className="font-semibold tabular-nums">
                    {d.memory_total_bytes
                      ? fmt(tr.server.usedOf, {
                          used: bytes(d.memory_total_bytes - (d.memory_available_bytes ?? 0)),
                          total: bytes(d.memory_total_bytes),
                        })
                      : tr.na}
                  </span>
                </div>
                {d.memory_used_percent !== null && <Meter percent={d.memory_used_percent} />}
              </div>
              <div className="py-2.5 text-sm">
                <div className="flex justify-between gap-4">
                  <span className="text-text-muted">{tr.server.disk}</span>
                  <span className="font-semibold tabular-nums">
                    {d.disk_total_bytes
                      ? fmt(tr.server.usedOf, {
                          used: bytes(d.disk_total_bytes - (d.disk_free_bytes ?? 0)),
                          total: bytes(d.disk_total_bytes),
                        })
                      : tr.na}
                  </span>
                </div>
                {d.disk_used_percent !== null && <Meter percent={d.disk_used_percent} />}
              </div>
              <p className="mt-1 text-xs text-text-dim">{fmt(tr.server.php, { version: d.php_version })}</p>
            </>
          )}
        </SectionCard>

        <SectionCard title={tr.hetzner.title} icon="building" section={s?.hetzner} loading={busy} tag="estimate">
          {(d) => (
            <>
              <Row
                label={tr.hetzner.type}
                value={
                  <>
                    {(d.server_type ?? "-").toUpperCase()}
                    {d.cores ? (
                      <p className="text-xs font-normal text-text-dim">
                        {fmt(tr.hetzner.spec, { cores: d.cores, memory: d.memory_gb ?? "-", disk: d.disk_gb ?? "-" })}
                      </p>
                    ) : null}
                  </>
                }
              />
              <Row label={tr.hetzner.status} value={<Pill tone={d.status === "running" ? "success" : "neutral"}>{d.status ?? "-"}</Pill>} />
              <Row label={tr.hetzner.location} value={d.location ?? "-"} />
              <Row
                label={tr.hetzner.backups}
                value={d.backups_enabled ? fmt(tr.hetzner.backupsOn, { percent: d.backup_percent }) : tr.hetzner.backupsOff}
              />
              <Row
                label={tr.hetzner.price}
                hint={tr.legend.estimate}
                value={d.price_monthly_gross_eur !== null ? fmt(tr.hetzner.perMonth, { amount: `EUR ${d.price_monthly_gross_eur.toFixed(2)}` }) : "-"}
              />
            </>
          )}
        </SectionCard>

        <SectionCard title={tr.video.title} icon="film" section={s?.bunny} loading={busy} tag="live_usage">
          {(d) => (
            <>
              <Row label={tr.video.videos} value={formatNumber(d.video_count)} />
              <Row label={tr.video.storage} value={bytes(d.storage_bytes)} />
              {d.account_connected ? (
                <>
                  <Row label={tr.video.bandwidth} value={bytes(d.bandwidth_month_bytes)} />
                  {d.requests_month !== undefined && d.requests_month !== null && (
                    <Row label={tr.video.requests} value={formatNumber(d.requests_month)} />
                  )}
                  {d.cache_hit_rate !== undefined && d.cache_hit_rate !== null && <Row label={tr.video.cacheHit} value={`${d.cache_hit_rate}%`} />}
                  {d.billing && (
                    <>
                      <Row label={<span className="inline-flex items-center gap-2">{tr.video.billedMonth} <TagPill tag="billed" /></span>} value={usd(d.billing.this_month_charges)} />
                      <Row label={tr.video.balance} hint={tr.video.balanceHint} value={usd(d.billing.balance)} />
                    </>
                  )}
                </>
              ) : (
                <p className="mt-3 rounded-lg bg-surface-2 p-2.5 text-xs text-text-muted">{tr.video.accountMissing}</p>
              )}
              <PartialNote errors={d.partial_errors} />
            </>
          )}
        </SectionCard>

        <SectionCard title={tr.storage.title} icon="layers" section={s?.r2} loading={busy} tag="live_usage">
          {(d) => (
            <>
              <Row label={tr.storage.total} value={bytes(d.storage_bytes)} />
              <Row label={tr.storage.objects} value={formatNumber(d.object_count)} />
              {d.class_a_month !== null && <Row label={tr.storage.classA} value={formatNumber(d.class_a_month)} />}
              {d.class_b_month !== null && <Row label={tr.storage.classB} value={formatNumber(d.class_b_month)} />}
              {d.buckets.length > 0 && (
                <div className="mt-3">
                  <p className="mb-1.5 text-xs font-semibold uppercase tracking-wider text-text-dim">{tr.storage.buckets}</p>
                  <ul className="flex flex-col gap-1 text-sm">
                    {d.buckets.map((b) => (
                      <li key={b.name} className="flex justify-between gap-3 rounded-lg bg-surface-2 px-3 py-2">
                        <span className="truncate font-medium">{b.name}</span>
                        <span className="shrink-0 tabular-nums text-text-muted">
                          {bytes(b.storage_bytes)} · {formatNumber(b.object_count)}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
              <PartialNote errors={d.partial_errors} />
            </>
          )}
        </SectionCard>

        <SectionCard title={tr.database.title} icon="grid" section={s?.database} loading={busy} tag="live_usage">
          {(d) => (
            <>
              <Row label={tr.database.engine} value={d.driver} />
              <Row label={tr.database.size} value={bytes(d.size_bytes)} />
              {d.tables !== null && <Row label={tr.database.tables} value={formatNumber(d.tables)} />}
              <Row
                label={tr.database.redis}
                value={
                  !d.redis.in_use ? (
                    <span className="text-xs font-normal text-text-muted">{tr.database.redisOff}</span>
                  ) : d.redis.ok ? (
                    d.redis.max_memory_bytes ? (
                      fmt(tr.server.usedOf, { used: bytes(d.redis.used_memory_bytes), total: bytes(d.redis.max_memory_bytes) })
                    ) : (
                      bytes(d.redis.used_memory_bytes)
                    )
                  ) : (
                    <span className="text-danger">{tr.database.redisDown}</span>
                  )
                }
              />
            </>
          )}
        </SectionCard>

        <SectionCard title={tr.failures.title} icon="alert" section={s?.app} loading={busy} tag="live_usage">
          {(d) => {
            const bad = (n: number | null) => (
              <span className={cn(n && n > 0 ? "text-danger" : "text-text")}>{n === null ? tr.na : formatNumber(n)}</span>
            );
            return (
              <>
                <Row label={tr.failures.withVideo} value={formatNumber(d.episodes_with_video)} />
                <Row label={tr.failures.processing} value={formatNumber(d.episodes_processing)} />
                <Row label={tr.failures.failed} value={bad(d.episodes_failed)} />
                <Row label={tr.failures.stuck} value={bad(d.episodes_stuck)} />
                <Row label={tr.failures.samplesProcessing} value={formatNumber(d.samples_processing)} />
                <Row label={tr.failures.samplesFailed} value={bad(d.samples_failed)} />
                <Row label={tr.failures.failedJobs} value={bad(d.failed_jobs)} />
              </>
            );
          }}
        </SectionCard>
      </div>

      <section className="mt-4 rounded-2xl border border-primary/40 bg-primary/5 p-5">
        <div className="flex items-start gap-3">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-primary/15 text-primary">
            <Icon name="shield" size={18} />
          </span>
          <div className="min-w-0">
            <h2 className="text-[15px] font-bold">{tr.caps.title}</h2>
            <p className="mt-1 text-sm text-text-muted">{tr.caps.body}</p>
          </div>
        </div>
        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <div>
            <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-success">{tr.caps.canCap}</p>
            <ul className="flex flex-col gap-2 text-sm">
              {tr.caps.canCapItems.map((item) => (
                <li key={item} className="flex gap-2">
                  <Icon name="check" size={16} className="mt-0.5 shrink-0 text-success" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-primary">{tr.caps.cannotCap}</p>
            <ul className="flex flex-col gap-2 text-sm">
              {tr.caps.cannotCapItems.map((item) => (
                <li key={item} className="flex gap-2">
                  <Icon name="alert" size={16} className="mt-0.5 shrink-0 text-primary" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>
    </>
  );
}
