"use client";

import Link from "next/link";
import { Card, DataTable, PageHeader, StatCard, Thumb } from "@/components/portal/Kit";
import { TrendChart } from "@/components/portal/Charts";
import { Button } from "@/components/ui/Button";
import { ApiDownState } from "@/components/ui/Feedback";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { useApi } from "@/lib/hooks";
import { formatCompact, formatMoney, formatNumber, pickNum, toSeries } from "@/lib/format";

interface DramaRow {
  id: number;
  title: string;
  slug?: string;
  poster_url?: string | null;
  views: number;
  episodes: number;
  earnings: number;
}

function sub(obj: unknown, key: string): unknown {
  return obj && typeof obj === "object" ? (obj as Record<string, unknown>)[key] : undefined;
}

export default function StudioDashboard() {
  const { data, loading, error, reload } = useApi<Record<string, unknown>>("/studio/dashboard");
  const s = useT().studio;
  const t = s.dashboard;

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
    title: String(r.title ?? (r.drama as { title?: string })?.title ?? s.untitled),
    slug: (r.slug as string) ?? undefined,
    poster_url: (r.poster_url as string) ?? null,
    views: pickNum(r, "views", "views_total"),
    episodes: pickNum(r, "episodes", "episodes_count", "total_episodes"),
    earnings: pickNum(r, "earnings", "earnings_total", "amount"),
  }));

  if (error && !data) {
    return (
      <>
        <PageHeader title={t.title} />
        <ApiDownState action={<Button onClick={reload}>{s.retry}</Button>} />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t.title}
        description={t.description}
        actions={
          <Button href="/studio/dramas/new" size="sm">
            {t.newDrama}
          </Button>
        }
      />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard label={t.totalViews} icon="eye" value={formatCompact(kpi.viewsTotal)} hint={fmt(t.today, { n: formatNumber(kpi.viewsToday) })} loading={loading} />
        <StatCard label={t.views30} icon="chart" accent="info" value={formatCompact(kpi.views30)} hint={fmt(t.uniqueWatchers, { n: formatNumber(kpi.watchers) })} loading={loading} />
        <StatCard label={t.totalEarnings} icon="wallet" accent="success" value={formatMoney(kpi.earnTotal)} hint={fmt(t.thisMonth, { amount: formatMoney(kpi.earnMonth) })} loading={loading} />
        <StatCard label={t.pendingPayout} icon="payout" accent="gold" value={formatMoney(kpi.pending)} loading={loading} />
      </div>

      <div className="mt-4 grid gap-4 xl:grid-cols-2">
        <Card title={t.dailyViews}>
          <TrendChart id="views" data={viewsChart} loading={loading} format={(v) => fmt(t.viewsValue, { n: formatNumber(v) })} />
        </Card>
        <Card title={t.dailyEarnings}>
          <TrendChart id="earn" data={earningsChart} loading={loading} color="#FFFFFF" format={(v) => formatMoney(v)} />
        </Card>
      </div>

      <h2 className="mb-3 mt-8 text-lg font-bold">{t.perDrama}</h2>
      <DataTable
        loading={loading}
        rows={[...dramas].sort((a, b) => b.views - a.views)}
        rowKey={(r) => r.id}
        columns={[
          {
            key: "title",
            header: s.cols.drama,
            render: (r) => (
              <div className="flex items-center gap-3">
                <Thumb src={r.poster_url} alt={r.title} />
                <Link href={`/studio/dramas/${r.id}`} className="font-semibold hover:text-primary">
                  {r.title}
                </Link>
              </div>
            ),
          },
          { key: "views", header: s.cols.views, render: (r) => formatNumber(r.views) },
          { key: "episodes", header: s.cols.episodes, render: (r) => formatNumber(r.episodes) },
          { key: "earnings", header: s.cols.earnings, className: "text-right", render: (r) => <span className="font-semibold">{formatMoney(r.earnings)}</span> },
        ]}
      />
    </>
  );
}
