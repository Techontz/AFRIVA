"use client";

import Link from "next/link";
import { useState } from "react";
import { DataTable, PageHeader, StatCard, Thumb } from "@/components/portal/Kit";
import { RangeSelect } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { ApiDownState } from "@/components/ui/Feedback";
import { formatMoney, formatNumber } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { DASH, pct, watchTime, type Period, type SeriesAnalyticsRow } from "@/lib/portal";

export default function StudioAnalyticsPage() {
  const t = useT();
  const [days, setDays] = useState(30);
  const { data, loading, error, reload } = useApi<{ period: Period; series: SeriesAnalyticsRow[] }>("/studio/analytics", { days });
  const rows = data?.series ?? [];
  const sum = (k: keyof SeriesAnalyticsRow) => rows.reduce((a, r) => a + Number(r[k] || 0), 0);

  return (
    <>
      <PageHeader
        title="Analytics"
        description="Revenue and audience for each of your series."
        actions={<RangeSelect value={days} onChange={setDays} options={[7, 30, 90]} />}
      />
      {error && !data ? (
        <ApiDownState action={<Button onClick={reload}>{t("Retry")}</Button>} />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard label="Your earnings" icon="wallet" accent="success" loading={loading} value={sum("creator_earnings") ? formatMoney(sum("creator_earnings")) : DASH} />
            <StatCard label="Views" icon="eye" loading={loading} value={sum("views") ? formatNumber(sum("views")) : DASH} />
            <StatCard label="Unique viewers" icon="users" accent="info" loading={loading} value={sum("unique_viewers") ? formatNumber(sum("unique_viewers")) : DASH} hint="Summed across series" />
            <StatCard label="Watch time" icon="clock" loading={loading} value={watchTime(sum("watch_seconds"))} />
          </div>
          <h2 className="mb-3 mt-8 text-lg font-bold">{t("By series")}</h2>
          <DataTable
            loading={loading}
            rows={rows}
            rowKey={(r) => r.drama_id}
            columns={[
              {
                key: "title",
                header: "Series",
                render: (r) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={r.poster_url} alt={r.title} />
                    <Link href={`/studio/dramas/${r.drama_id}/analytics`} className="font-semibold hover:text-primary">
                      {r.title}
                    </Link>
                  </div>
                ),
              },
              { key: "rev", header: "Revenue (gross)", render: (r) => (r.revenue_gross ? formatMoney(r.revenue_gross) : DASH) },
              { key: "earn", header: "Your earnings", render: (r) => (r.creator_earnings ? formatMoney(r.creator_earnings) : DASH) },
              { key: "views", header: "Views", render: (r) => (r.views ? formatNumber(r.views) : DASH) },
              { key: "uv", header: "Unique viewers", render: (r) => (r.unique_viewers ? formatNumber(r.unique_viewers) : DASH) },
              { key: "wt", header: "Watch time", render: (r) => watchTime(r.watch_seconds) },
              { key: "done", header: "Completion", className: "text-right", render: (r) => (r.unique_viewers ? pct(r.completion_rate) : DASH) },
            ]}
          />
        </>
      )}
    </>
  );
}
