"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { LoadError } from "@/components/admin/helpers";
import { TrendChart } from "@/components/portal/Charts";
import { Card, DataTable, PageHeader, StatCard, Thumb } from "@/components/portal/Kit";
import { StatusPill } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { asArray } from "@/lib/api";
import { formatCompact, formatMoney, formatNumber, pickNum, toSeries } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import type { Company } from "@/lib/types";

type Stats = Record<string, unknown>;

export default function CompanyStatsPage() {
  const { id } = useParams<{ id: string }>();
  const { admin } = useT();
  const tr = admin.company;
  const col = admin.cols;
  const company = useApi<Company>(`/admin/companies/${id}`);
  const stats = useApi<Stats>(`/admin/companies/${id}/stats`);
  const s = stats.data ?? {};
  const loading = stats.loading;

  // Accept nested `{views:{total,today,last_30_days}}` or flat keys.
  const views = (typeof s.views === "object" && s.views ? s.views : s) as Record<string, unknown>;
  const earnings = (typeof s.earnings === "object" && s.earnings ? s.earnings : s) as Record<string, unknown>;
  const dramas = asArray<Record<string, unknown>>(s.dramas ?? s.per_drama ?? s.drama_stats);
  const c = company.data ?? ((s.company as Company | undefined) ?? null);

  return (
    <>
      <PageHeader
        back={
          <Link href="/admin/companies" className="inline-flex items-center gap-1 text-xs font-semibold text-text-muted hover:text-text">
            <Icon name="chevron-left" size={14} /> {admin.nav.companies}
          </Link>
        }
        title={c?.name ?? (company.loading ? admin.loading : fmt(tr.fallbackTitle, { id }))}
        description={
          c ? (
            <span className="inline-flex flex-wrap items-center gap-2">
              {c.country && <span>{c.country}</span>}
              <span>· {fmt(tr.share, { n: Number(c.revenue_share_percent) })}</span>
              <StatusPill status={c.status} />
            </span>
          ) : undefined
        }
      />

      {stats.error && !stats.data ? (
        <LoadError onRetry={stats.reload} />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
            <StatCard loading={loading} label={tr.totalViews} icon="eye" value={formatCompact(pickNum(views, "total", "views", "total_views"))} hint={fmt(tr.today, { n: formatNumber(pickNum(views, "today", "views_today")) })} />
            <StatCard loading={loading} label={tr.views30} icon="chart" accent="info" value={formatCompact(pickNum(views, "last_30d", "last_30_days", "30d", "month", "views_30d"))} />
            <StatCard loading={loading} label={tr.watchers} icon="users" accent="success" value={formatNumber(pickNum(s, "unique_watchers", "watchers"))} />
            <StatCard loading={loading} label={tr.totalEarnings} icon="wallet" accent="gold" value={formatMoney(pickNum(earnings, "total", "earnings", "total_earnings"))} hint={fmt(tr.earningsHint, { month: formatMoney(pickNum(earnings, "month", "this_month", "earnings_month")), pending: formatMoney(pickNum(earnings, "pending_payout", "pending")) })} />
          </div>

          <div className="mt-4 grid gap-4 xl:grid-cols-2">
            <Card title={tr.viewsChart}>
              <TrendChart id="co-views" data={toSeries(s.views_chart, "views")} loading={loading} color="#FFFFFF" format={(v) => formatNumber(v)} />
            </Card>
            <Card title={tr.earningsChart}>
              <TrendChart id="co-earn" data={toSeries(s.earnings_chart, "earnings", "amount")} loading={loading} format={(v) => formatMoney(v)} />
            </Card>
          </div>

          <h2 className="mb-3 mt-6 text-[15px] font-bold">{tr.breakdown}</h2>
          <DataTable
            loading={loading}
            rows={dramas}
            rowKey={(d) => String(d.id ?? d.slug ?? d.title)}
            columns={[
              {
                key: "title",
                header: col.drama,
                render: (d) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={d.poster_url as string | undefined} alt={String(d.title ?? "")} />
                    <span className="font-semibold">{String(d.title ?? "-")}</span>
                  </div>
                ),
              },
              { key: "eps", header: col.episodes, render: (d) => formatNumber(pickNum(d, "episodes", "total_episodes", "episodes_count")) },
              { key: "views", header: col.views, render: (d) => formatCompact(pickNum(d, "views")) },
              { key: "earn", header: col.earnings, render: (d) => formatMoney(pickNum(d, "earnings", "amount")) },
              { key: "status", header: col.status, render: (d) => (d.status ? <StatusPill status={String(d.status)} /> : "-") },
            ]}
          />
        </>
      )}
    </>
  );
}
