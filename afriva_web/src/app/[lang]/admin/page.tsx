"use client";

import Link from "next/link";
import { LoadError, methodLabel } from "@/components/admin/helpers";
import { RankBarChart, TrendChart } from "@/components/portal/Charts";
import { Card, DataTable, PageHeader, StatCard, Thumb } from "@/components/portal/Kit";
import { StatusPill } from "@/components/ui/Feedback";
import { useLocale, useT } from "@/i18n/client";
import { asArray } from "@/lib/api";
import { formatCompact, formatDate, formatMoney, formatNumber, pickNum, toSeries } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import type { Drama, Payment } from "@/lib/types";

type Dash = Record<string, unknown>;

export default function AdminDashboard() {
  const { data, loading, error, reload } = useApi<Dash>("/admin/dashboard");
  const tr = useT().admin.dashboard;
  const col = useT().admin.cols;
  const locale = useLocale();

  if (error && !data) {
    return (
      <>
        <PageHeader title={tr.title} />
        <LoadError onRetry={reload} />
      </>
    );
  }

  // Totals may live under `totals` or at the top level.
  const t = (data?.totals ?? data ?? {}) as Record<string, unknown>;
  const revenueSeries = toSeries(data?.revenue_chart, "revenue", "amount", "total");
  const byMethod = asArray<Record<string, unknown>>(data?.revenue_by_method).map((r) => ({
    label: String(r.name ?? r.method ?? r.payment_method_code ?? r.code ?? "-"),
    value: pickNum(r, "value", "amount", "total", "revenue"),
  }));
  const topDramas = asArray<Drama & Record<string, unknown>>(data?.top_dramas);
  const recent = asArray<Payment>(data?.recent_payments);

  return (
    <>
      <PageHeader title={tr.title} description={tr.description} />

      <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
        <StatCard loading={loading} label={tr.totalRevenue} icon="wallet" value={formatMoney(pickNum(t, "revenue", "total_revenue"))} />
        <StatCard loading={loading} label={tr.revenueToday} icon="sparkles" accent="gold" value={formatMoney(pickNum(t, "revenue_today"))} />
        <StatCard loading={loading} label={tr.revenueMonth} icon="chart" accent="success" value={formatMoney(pickNum(t, "revenue_month", "revenue_this_month"))} />
        <StatCard loading={loading} label={tr.activeSubscribers} icon="crown" accent="gold" value={formatNumber(pickNum(t, "active_subscribers", "subscribers"))} />
        <StatCard loading={loading} label={tr.users} icon="users" accent="info" value={formatNumber(pickNum(t, "users", "total_users"))} />
        <StatCard loading={loading} label={tr.companies} icon="building" value={formatNumber(pickNum(t, "companies"))} />
        <StatCard loading={loading} label={tr.dramas} icon="film" accent="info" value={formatNumber(pickNum(t, "dramas"))} />
        <StatCard loading={loading} label={tr.totalViews} icon="eye" accent="success" value={formatCompact(pickNum(t, "views", "total_views"))} />
      </div>

      <div className="mt-4 grid gap-4 xl:grid-cols-3">
        <Card title={tr.revenue30} className="xl:col-span-2">
          <TrendChart id="admin-rev" data={revenueSeries} loading={loading} format={(v) => formatMoney(v)} />
        </Card>
        <Card title={tr.revenueByMethod}>
          <RankBarChart data={byMethod} loading={loading} format={(v) => formatMoney(v)} />
        </Card>
      </div>

      <div className="mt-4 grid gap-4 xl:grid-cols-2">
        <div>
          <h2 className="mb-3 text-[15px] font-bold">{tr.topDramas}</h2>
          <DataTable
            loading={loading}
            rows={topDramas}
            rowKey={(d) => d.id}
            columns={[
              {
                key: "title",
                header: col.drama,
                render: (d) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={d.poster_url} alt={d.title} />
                    <div className="min-w-0">
                      <p className="truncate font-semibold">{d.title}</p>
                      <p className="truncate text-xs text-text-dim">{d.company?.name}</p>
                    </div>
                  </div>
                ),
              },
              { key: "views", header: col.views, render: (d) => formatCompact(pickNum(d, "views", "period_views")) },
              {
                key: "rev",
                header: col.revenue,
                render: (d) => formatMoney(pickNum(d, "revenue", "earnings", "amount")),
              },
            ]}
          />
        </div>
        <div>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-[15px] font-bold">{tr.recentPayments}</h2>
            <Link href="/admin/payments" className="text-xs font-semibold text-primary hover:underline">
              {tr.viewAll}
            </Link>
          </div>
          <DataTable
            loading={loading}
            rows={recent}
            rowKey={(p) => p.id ?? p.reference}
            columns={[
              {
                key: "user",
                header: col.user,
                render: (p) => (
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{p.user?.name ?? "-"}</p>
                    <p className="truncate font-mono text-[11px] text-text-dim">{p.reference}</p>
                  </div>
                ),
              },
              { key: "method", header: col.method, render: (p) => methodLabel(p) },
              { key: "amount", header: col.amount, render: (p) => formatMoney(p.amount, p.currency) },
              { key: "status", header: col.status, render: (p) => <StatusPill status={p.status} /> },
              { key: "date", header: col.date, render: (p) => formatDate(p.created_at, false, locale) },
            ]}
          />
        </div>
      </div>
    </>
  );
}
