"use client";

import { useState } from "react";
import { LoadError, methodLabel } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { StatusPill } from "@/components/ui/Feedback";
import { Select } from "@/components/ui/Form";
import { asArray } from "@/lib/api";
import { formatDate, formatMoney } from "@/lib/format";
import { useApi, useDebounced, useList } from "@/lib/hooks";
import type { Payment, PaymentMethod } from "@/lib/types";

export default function PaymentsPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [method, setMethod] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { items, meta, loading, error, reload } = useList<Payment>("/admin/payments", {
    search: q,
    status,
    payment_method: method,
    page,
  });
  const methods = asArray<PaymentMethod>(useApi<unknown>("/admin/payment-methods").data);

  return (
    <>
      <PageHeader title="Payments" description="Every checkout attempt across all payment methods." />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder="Reference, name, phone…"
        />
        <Select
          className="sm:w-40"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          aria-label="Filter by status"
        >
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="success">Success</option>
          <option value="failed">Failed</option>
          <option value="cancelled">Cancelled</option>
        </Select>
        <Select
          className="sm:w-44"
          value={method}
          onChange={(e) => {
            setMethod(e.target.value);
            setPage(1);
          }}
          aria-label="Filter by method"
        >
          <option value="">All methods</option>
          {methods.map((m) => (
            <option key={m.code} value={m.code}>
              {m.name}
            </option>
          ))}
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(p) => p.id ?? p.reference}
            columns={[
              { key: "ref", header: "Reference", render: (p) => <span className="font-mono text-xs">{p.reference}</span> },
              {
                key: "user",
                header: "User",
                render: (p) => (
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{p.user?.name ?? "—"}</p>
                    <p className="truncate text-xs text-text-dim">{p.phone ?? p.user?.email ?? p.user?.phone ?? ""}</p>
                  </div>
                ),
              },
              { key: "plan", header: "Plan", render: (p) => p.plan?.name ?? "—" },
              { key: "method", header: "Method", render: (p) => methodLabel(p) },
              { key: "amount", header: "Amount", render: (p) => <span className="font-semibold">{formatMoney(p.amount, p.currency)}</span> },
              { key: "status", header: "Status", render: (p) => <StatusPill status={p.status} /> },
              { key: "date", header: "Date", render: (p) => formatDate(p.paid_at ?? p.created_at, true) },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
    </>
  );
}
