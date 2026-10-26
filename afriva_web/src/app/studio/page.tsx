"use client";

import Link from "next/link";
import { Card, DataTable, PageHeader, StatCard, Thumb } from "@/components/portal/Kit";
import { TrendChart } from "@/components/portal/Charts";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Pill } from "@/components/ui/Feedback";
import { ReviewStatusPill } from "@/components/portal/ScopeKit";
import { REVIEW_LABEL } from "@/lib/portal";
import type { ReviewStatus } from "@/lib/types";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { formatCompact, formatMoney, formatNumber, pickNum, toSeries } from "@/lib/format";

interface DramaRow {
  id: number;
  title: string;
  slug?: string;
  poster_url?: string | null;
  views: number;
  episodes: number;
  earnings: number;
  review_status?: ReviewStatus;
  is_live?: boolean;
}

function sub(obj: unknown, key: string): unknown {
  return obj && typeof obj === "object" ? (obj as Record<string, unknown>)[key] : undefined;
}

export default function StudioDashboard() {
  const t = useT();
  const { data, loading, error, reload } = useApi<Record<string, unknown>>("/studio/dashboard");

  const d = data ?? {};
  const views = sub(d, "views");
  const earnings = sub(d, "earnings");
  const viewsObj = typeof views === "object" ? views : d;
  const earnObj = typeof earnings === "object" ? earnings : d;

  const kpi = {
    viewsTotal: typeof views === "number" ? views : pickNum(viewsObj, "total", "views_total", "total_views"),
    viewsToday: pickNum(viewsObj, "today", "views_today"),
    views30: pickNum(viewsObj, "last_30_days", "30d", "month", "views_30d", "last_30d"),
    watchers: pickNum(d, "unique_watchers", "watchers"),
    earnTotal: typeof earnings === "number" ? earnings : pickNum(earnObj, "total", "earnings_total", "total_earnings"),
    earnMonth: pickNum(earnObj, "month", "this_month", "earnings_month"),
    pending: pickNum(earnObj, "pending_payout", "pending", "balance"),
  };

  const viewsChart = toSeries(sub(d, "views_chart"), "views");
  const earningsChart = toSeries(sub(d, "earnings_chart"), "amount", "earnings");
  const rawDramas = (sub(d, "dramas") ?? sub(d, "per_drama") ?? sub(d, "drama_stats")) as unknown;
  const dramas: DramaRow[] = (Array.isArray(rawDramas) ? rawDramas : []).map((r: Record<string, unknown>) => ({
    id: Number(r.id ?? r.drama_id),
    title: String(r.title ?? (r.drama as { title?: string })?.title ?? t("Untitled")),
    slug: (r.slug as string) ?? undefined,
    poster_url: (r.poster_url as string) ?? null,
    views: pickNum(r, "views", "views_total"),
    episodes: pickNum(r, "episodes", "episodes_count", "total_episodes"),
    earnings: pickNum(r, "earnings", "earnings_total", "amount"),
    review_status: (r.review_status as ReviewStatus) ?? undefined,
    is_live: Boolean(r.is_live),
  }));
  const reviewCounts = (sub(d, "review_counts") ?? {}) as Partial<Record<ReviewStatus, number>>;

  if (error && !data) {
    return (
      <>
        <PageHeader title={t("Studio dashboard")} />
        <ApiDownState action={<Button onClick={reload}>{t("Retry")}</Button>} />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t("Studio dashboard")}
        description={t("How your series are performing across AFRIVA.")}
        actions={
          <Button href="/studio/dramas/new" size="sm">
            {t("Submit your work")}
          </Button>
        }
      />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard label={t("Total views")} icon="eye" value={formatCompact(kpi.viewsTotal)} hint={t("{n} today", { n: formatNumber(kpi.viewsToday) })} loading={loading} />
        <StatCard label={t("Views · 30 days")} icon="chart" accent="info" value={formatCompact(kpi.views30)} hint={t("{n} unique watchers", { n: formatNumber(kpi.watchers) })} loading={loading} />
        <StatCard label={t("Total earnings")} icon="wallet" accent="success" value={formatMoney(kpi.earnTotal)} hint={t("{amount} this month", { amount: formatMoney(kpi.earnMonth) })} loading={loading} />
        <StatCard label={t("Pending payout")} icon="payout" accent="gold" value={formatMoney(kpi.pending)} loading={loading} />
      </div>

      <Card title={t("Review status")} className="mt-4">
        <div className="flex flex-wrap gap-2">
          {(Object.keys(REVIEW_LABEL) as ReviewStatus[]).map((s) => (
            <Link key={s} href={`/studio/dramas?review_status=${s}`} className="flex items-center gap-2 rounded-full bg-surface-2 py-1 pl-1 pr-3 text-sm">
              <ReviewStatusPill status={s} />
              <span className="font-bold">{formatNumber(reviewCounts[s] ?? 0)}</span>
            </Link>
          ))}
        </div>
      </Card>

      <div className="mt-4 grid gap-4 xl:grid-cols-2">
        <Card title={t("Daily views · last 30 days")}>
          <TrendChart id="views" data={viewsChart} loading={loading} format={(v) => t("{n} views", { n: formatNumber(v) })} />
        </Card>
        <Card title={t("Daily earnings · last 30 days")}>
          <TrendChart id="earn" data={earningsChart} loading={loading} color="#FFFFFF" format={(v) => formatMoney(v)} />
        </Card>
      </div>

      <h2 className="mb-3 mt-8 text-lg font-bold">{t("Per-series performance")}</h2>
      <DataTable
        loading={loading}
        rows={[...dramas].sort((a, b) => b.views - a.views)}
        rowKey={(r) => r.id}
        columns={[
          {
            key: "title",
            header: t("Series"),
            render: (r) => (
              <div className="flex items-center gap-3">
                <Thumb src={r.poster_url} alt={r.title} />
                <Link href={`/studio/dramas/${r.id}`} className="font-semibold hover:text-primary">
                  {r.title}
                </Link>
              </div>
            ),
          },
          {
            key: "review",
            header: t("Review"),
            render: (r) => (
              <div className="flex flex-wrap gap-1">
                <ReviewStatusPill status={r.review_status} />
                {r.is_live && <Pill tone="success">{t("Live")}</Pill>}
              </div>
            ),
          },
          { key: "views", header: t("Views"), render: (r) => formatNumber(r.views) },
          { key: "episodes", header: t("Episodes"), render: (r) => formatNumber(r.episodes) },
          { key: "earnings", header: t("Earnings"), className: "text-right", render: (r) => <span className="font-semibold">{formatMoney(r.earnings)}</span> },
        ]}
      />
    </>
  );
}
