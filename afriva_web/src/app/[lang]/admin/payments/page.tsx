"use client";

import { useState } from "react";
import { LoadError, methodLabel } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { StatusPill } from "@/components/ui/Feedback";
import { Select } from "@/components/ui/Form";
import { useLocale, useT } from "@/i18n/client";
import { asArray } from "@/lib/api";
import { formatDate, formatMoney } from "@/lib/format";
import { useApi, useDebounced, useList } from "@/lib/hooks";
import type { Payment, PaymentMethod } from "@/lib/types";

export default function PaymentsPage() {
  const { admin, common } = useT();
  const locale = useLocale();
  const tr = admin.payments;
  const col = admin.cols;
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
      <PageHeader title={admin.nav.payments} description={tr.description} />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder={tr.search}
        />
        <Select
          className="sm:w-40"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          aria-label={admin.filterStatus}
        >
          <option value="">{admin.allStatuses}</option>
          <option value="pending">{common.status.pending}</option>
          <option value="success">{common.status.success}</option>
          <option value="failed">{common.status.failed}</option>
          <option value="cancelled">{common.status.cancelled}</option>
        </Select>
        <Select
          className="sm:w-44"
          value={method}
          onChange={(e) => {
            setMethod(e.target.value);
            setPage(1);
          }}
          aria-label={tr.filterMethod}
        >
          <option value="">{tr.allMethods}</option>
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
              { key: "ref", header: col.reference, render: (p) => <span className="font-mono text-xs">{p.reference}</span> },
              {
                key: "user",
                header: col.user,
                render: (p) => (
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{p.user?.name ?? "-"}</p>
                    <p className="truncate text-xs text-text-dim">{p.phone ?? p.user?.email ?? p.user?.phone ?? ""}</p>
                  </div>
                ),
              },
              { key: "plan", header: col.plan, render: (p) => p.plan?.name ?? "-" },
              { key: "method", header: col.method, render: (p) => methodLabel(p) },
              { key: "amount", header: col.amount, render: (p) => <span className="font-semibold">{formatMoney(p.amount, p.currency)}</span> },
              { key: "status", header: col.status, render: (p) => <StatusPill status={p.status} /> },
              { key: "date", header: col.date, render: (p) => formatDate(p.paid_at ?? p.created_at, true, locale) },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
    </>
  );
}
