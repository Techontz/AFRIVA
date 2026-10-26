"use client";

import { useState } from "react";
import { formatMoney, formatNumber } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { DASH, pct, watchTime, type DramaAnalytics } from "@/lib/portal";
import { Button } from "../ui/Button";
import { ApiDownState, Pill } from "../ui/Feedback";
import { RankBarChart } from "./Charts";
import { Card, DataTable, PageHeader, StatCard } from "./Kit";
import { DropOffChart, RangeSelect } from "./ScopeKit";

/** Per-series analytics (scope §06): revenue, views, unique viewers, watch time, completion, reach and drop-off per episode. */
export function DramaAnalyticsView({ path, back }: { path: string; back?: React.ReactNode }) {
  const t = useT();
  const [days, setDays] = useState(30);
  const { data, loading, error, reload } = useApi<DramaAnalytics>(path, { days });
  const eps = data?.episodes ?? [];

  return (
    <>
      <PageHeader
        back={back}
        title={data?.drama.title ?? t("Series analytics")}
        description={t("Every number comes from real views, playback events and payments.")}
        actions={<RangeSelect value={days} onChange={setDays} options={[7, 30, 90]} />}
      />
      {error && !data ? (
        <ApiDownState action={<Button onClick={reload}>{t("Retry")}</Button>} />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard label="Revenue (gross)" icon="wallet" accent="success" loading={loading} value={data?.totals.revenue_gross ? formatMoney(data.totals.revenue_gross) : DASH} />
            <StatCard label="Views" icon="eye" loading={loading} value={data?.totals.views ? formatNumber(data.totals.views) : DASH} />
            <StatCard label="Unique viewers" icon="users" accent="info" loading={loading} value={data?.totals.unique_viewers ? formatNumber(data.totals.unique_viewers) : DASH} />
            <StatCard label="Watch time" icon="clock" loading={loading} value={watchTime(data?.totals.watch_seconds)} />
          </div>
          <div className="mt-4 grid gap-4 xl:grid-cols-2">
            <Card title="Where viewers stop watching">
              <DropOffChart data={data?.drop_off ?? []} loading={loading} />
            </Card>
            <Card title="Viewers reaching each episode">
              <RankBarChart
                loading={loading}
                data={eps.filter((e) => e.unique_viewers > 0).slice(0, 20).map((e) => ({ label: t("EP {n}", { n: e.number }), value: e.unique_viewers }))}
                format={(v) => formatNumber(v)}
              />
            </Card>
          </div>
          <h2 className="mb-3 mt-8 text-lg font-bold">{t("Per episode")}</h2>
          <DataTable
            loading={loading}
            rows={eps}
            rowKey={(e) => e.episode_id}
            columns={[
              {
                key: "n",
                header: "Episode",
                render: (e) => (
                  <div className="flex items-center gap-2">
                    <span className="font-bold">{e.number}</span>
                    {e.is_free ? <Pill tone="success">{t("Free")}</Pill> : <Pill tone="gold">{t("Locked")}</Pill>}
                  </div>
                ),
              },
              { key: "views", header: "Views", render: (e) => (e.views ? formatNumber(e.views) : DASH) },
              { key: "uv", header: "Unique viewers", render: (e) => (e.unique_viewers ? formatNumber(e.unique_viewers) : DASH) },
              { key: "reach", header: "Reach vs EP 1", render: (e) => (e.unique_viewers ? pct(e.reach_rate) : DASH) },
              { key: "wt", header: "Watch time", render: (e) => watchTime(e.watch_seconds) },
              { key: "done", header: "Completion", render: (e) => (e.unique_viewers ? pct(e.completion_rate) : DASH) },
              { key: "avg", header: "Avg. watched", render: (e) => (e.unique_viewers ? pct(e.avg_percent_watched) : DASH) },
              { key: "rev", header: "Revenue (gross)", className: "text-right", render: (e) => (e.revenue_gross ? formatMoney(e.revenue_gross) : DASH) },
            ]}
          />
        </>
      )}
    </>
  );
}
