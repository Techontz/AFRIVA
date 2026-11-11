"use client";

import { useState } from "react";
import { DataTable, PageHeader, Pagination, StatCard, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { ApiDownState, EmptyState, Pill, type Tone } from "@/components/ui/Feedback";
import { Select } from "@/components/ui/Form";
import { useLocale, useT } from "@/i18n/client";
import { formatDate, formatMoney, pickNum } from "@/lib/format";
import { useList } from "@/lib/hooks";
import type { Earning } from "@/lib/types";

const SOURCES: Record<string, { label: "vipPool" | "episodePack" | "coins"; tone: Tone }> = {
  subscription_pool: { label: "vipPool", tone: "info" },
  episode_pack: { label: "episodePack", tone: "brand" },
  coins: { label: "coins", tone: "gold" },
};

export default function StudioEarningsPage() {
  const s = useT().studio;
  const t = s.earnings;
  const locale = useLocale();
  const [page, setPage] = useState(1);
  const [source, setSource] = useState("");
  const { items, meta, loading, error, reload } = useList<Earning>("/studio/earnings", { page, per_page: 25, source });

  // Totals: prefer server-provided `meta.totals` / `meta.total_amount`, else sum the visible page.
  const m = (meta ?? {}) as unknown as Record<string, unknown>;
  const totals = (m.totals ?? m.summary ?? null) as Record<string, unknown> | null;
  const pageSum = (src?: string) => items.filter((e) => !src || e.source === src).reduce((s, e) => s + Number(e.amount || 0), 0);
  const fromServer = !!totals;
  const total = fromServer ? pickNum(totals, "total", "all", "amount") || pickNum(m, "total_amount") : pageSum();
  const bySource = (k: string) => (fromServer ? pickNum(totals, k) : pageSum(k));

  return (
    <>
      <PageHeader title={t.title} description={t.description} />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard label={fromServer ? t.totalEarned : t.totalPage} icon="wallet" accent="success" value={formatMoney(total)} loading={loading && !items.length} />
        <StatCard label={t.vipPool} icon="crown" accent="info" value={formatMoney(bySource("subscription_pool"))} loading={loading && !items.length} />
        <StatCard label={t.episodePacks} icon="layers" value={formatMoney(bySource("episode_pack"))} loading={loading && !items.length} />
        <StatCard label={t.coinUnlocks} icon="coin" accent="gold" value={formatMoney(bySource("coins"))} loading={loading && !items.length} />
      </div>

      <div className="mt-6">
        <Toolbar>
          <Select
            className="h-10 rounded-full py-0 sm:w-52"
            value={source}
            onChange={(e) => {
              setSource(e.target.value);
              setPage(1);
            }}
            aria-label={t.filterSource}
          >
            <option value="">{t.allSources}</option>
            {Object.entries(SOURCES).map(([k, v]) => (
              <option key={k} value={k}>
                {t[v.label]}
              </option>
            ))}
          </Select>
        </Toolbar>
        {error && !items.length ? (
          <ApiDownState action={<Button onClick={reload}>{s.retry}</Button>} />
        ) : (
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(e) => e.id}
            empty={<EmptyState className="border-0 bg-transparent" icon="wallet" title={t.none} description={t.noneHint} />}
            columns={[
              { key: "date", header: s.cols.date, render: (e) => formatDate(e.period_date ?? e.created_at, false, locale) },
              {
                key: "source",
                header: s.cols.source,
                render: (e) => <Pill tone={SOURCES[e.source]?.tone ?? "neutral"}>{SOURCES[e.source] ? t[SOURCES[e.source]!.label] : e.source}</Pill>,
              },
              { key: "drama", header: s.cols.drama, render: (e) => e.drama?.title ?? <span className="text-text-dim">{t.allDramas}</span> },
              {
                key: "amount",
                header: s.cols.amount,
                className: "text-right",
                render: (e) => <span className="font-semibold text-success">+{formatMoney(e.amount)}</span>,
              },
            ]}
          />
        )}
        <Pagination meta={meta} onPage={setPage} />
      </div>
    </>
  );
}
