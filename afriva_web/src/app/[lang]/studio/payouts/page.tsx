"use client";

import { useState } from "react";
import { DataTable, PageHeader, Pagination, StatCard } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { ApiDownState, EmptyState, StatusPill } from "@/components/ui/Feedback";
import { useLocale, useT } from "@/i18n/client";
import { formatDate, formatMoney } from "@/lib/format";
import { useList } from "@/lib/hooks";
import type { Payout } from "@/lib/types";

export default function StudioPayoutsPage() {
  const s = useT().studio;
  const t = s.payouts;
  const locale = useLocale();
  const [page, setPage] = useState(1);
  const { items, meta, loading, error, reload } = useList<Payout>("/studio/payouts", { page, per_page: 25 });
  const paid = items.filter((p) => p.status === "paid").reduce((s, p) => s + Number(p.amount || 0), 0);
  const pending = items.filter((p) => p.status === "pending").reduce((s, p) => s + Number(p.amount || 0), 0);
  const last = items.filter((p) => p.paid_at).sort((a, b) => String(b.paid_at).localeCompare(String(a.paid_at)))[0];
  const busy = loading && !items.length;

  return (
    <>
      <PageHeader title={t.title} description={t.description} />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard label={t.paidOut} icon="check" accent="success" value={formatMoney(paid)} loading={busy} />
        <StatCard label={t.pending} icon="clock" accent="gold" value={formatMoney(pending)} loading={busy} />
        <StatCard
          label={t.last}
          icon="payout"
          accent="info"
          value={last ? formatMoney(last.amount) : "-"}
          hint={last ? formatDate(last.paid_at, false, locale) : t.none}
          loading={busy}
        />
      </div>
      <div className="mt-6">
        {error && !items.length ? (
          <ApiDownState action={<Button onClick={reload}>{s.retry}</Button>} />
        ) : (
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(p) => p.id}
            empty={<EmptyState className="border-0 bg-transparent" icon="payout" title={t.none} description={t.noneHint} />}
            columns={[
              { key: "date", header: s.cols.created, render: (p) => formatDate(p.created_at, false, locale) },
              { key: "ref", header: s.cols.reference, render: (p) => <span className="font-mono text-xs">{p.reference || "-"}</span> },
              { key: "status", header: s.cols.status, render: (p) => <StatusPill status={p.status} /> },
              { key: "paid", header: s.cols.paidOn, render: (p) => formatDate(p.paid_at, false, locale) },
              { key: "notes", header: s.cols.notes, render: (p) => <span className="text-text-muted">{p.notes || "-"}</span> },
              { key: "amount", header: s.cols.amount, className: "text-right", render: (p) => <span className="font-semibold">{formatMoney(p.amount)}</span> },
            ]}
          />
        )}
        <Pagination meta={meta} onPage={setPage} />
      </div>
    </>
  );
}
