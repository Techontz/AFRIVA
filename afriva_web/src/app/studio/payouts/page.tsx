"use client";

import { useState } from "react";
import { DataTable, PageHeader, Pagination, StatCard } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { ApiDownState, EmptyState, StatusPill } from "@/components/ui/Feedback";
import { formatDate, formatMoney } from "@/lib/format";
import { useList } from "@/lib/hooks";
import type { Payout } from "@/lib/types";

export default function StudioPayoutsPage() {
  const [page, setPage] = useState(1);
  const { items, meta, loading, error, reload } = useList<Payout>("/studio/payouts", { page, per_page: 25 });
  const paid = items.filter((p) => p.status === "paid").reduce((s, p) => s + Number(p.amount || 0), 0);
  const pending = items.filter((p) => p.status === "pending").reduce((s, p) => s + Number(p.amount || 0), 0);
  const last = items.filter((p) => p.paid_at).sort((a, b) => String(b.paid_at).localeCompare(String(a.paid_at)))[0];
  const busy = loading && !items.length;

  return (
    <>
      <PageHeader title="Payouts" description="Transfers from Afriva to your studio. Payouts are issued by the Afriva finance team." />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard label="Paid out" icon="check" accent="success" value={formatMoney(paid)} loading={busy} />
        <StatCard label="Pending" icon="clock" accent="gold" value={formatMoney(pending)} loading={busy} />
        <StatCard
          label="Last payout"
          icon="payout"
          accent="info"
          value={last ? formatMoney(last.amount) : "—"}
          hint={last ? formatDate(last.paid_at) : "No payouts yet"}
          loading={busy}
        />
      </div>
      <div className="mt-6">
        {error && !items.length ? (
          <ApiDownState action={<Button onClick={reload}>Retry</Button>} />
        ) : (
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(p) => p.id}
            empty={<EmptyState className="border-0 bg-transparent" icon="payout" title="No payouts yet" description="Once Afriva pays out your earnings, they'll be listed here." />}
            columns={[
              { key: "date", header: "Created", render: (p) => formatDate(p.created_at) },
              { key: "ref", header: "Reference", render: (p) => <span className="font-mono text-xs">{p.reference || "—"}</span> },
              { key: "status", header: "Status", render: (p) => <StatusPill status={p.status} /> },
              { key: "paid", header: "Paid on", render: (p) => formatDate(p.paid_at) },
              { key: "notes", header: "Notes", render: (p) => <span className="text-text-muted">{p.notes || "—"}</span> },
              { key: "amount", header: "Amount", className: "text-right", render: (p) => <span className="font-semibold">{formatMoney(p.amount)}</span> },
            ]}
          />
        )}
        <Pagination meta={meta} onPage={setPage} />
      </div>
    </>
  );
}
