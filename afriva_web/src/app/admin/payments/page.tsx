"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError, methodLabel } from "@/components/admin/helpers";
import { Card, DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { Notice } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { Pill, Skeleton, StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { api, asArray, errorMessage } from "@/lib/api";
import { cn, formatDate, formatMoney, formatNumber } from "@/lib/format";
import { useApi, useDebounced, useList } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import type { PaymentDetail } from "@/lib/portal";
import type { CoinTransaction, CoinTransactionType, Payment, PaymentMethod } from "@/lib/types";

const COIN_TYPE_LABEL: Record<CoinTransactionType, string> = {
  purchase: "Purchase",
  bonus: "Bonus",
  unlock: "Episode unlock",
  admin_adjust: "Admin adjustment",
  refund: "Refund",
};

/** Miamala: payments (with refunds, fees and receipts) and the coin ledger. */
export default function PaymentsPage() {
  const t = useT();
  const [tab, setTab] = useState<"payments" | "coins">("payments");
  return (
    <>
      <PageHeader title="Transactions" description="Every checkout attempt, refunds and the coin ledger." />
      <div className="mb-4 flex gap-2" role="tablist">
        {(
          [
            ["payments", "Payments"],
            ["coins", "Coin ledger"],
          ] as const
        ).map(([k, label]) => (
          <button
            key={k}
            role="tab"
            aria-selected={tab === k}
            onClick={() => setTab(k)}
            className={cn("rounded-full px-4 py-2 text-sm font-semibold transition", tab === k ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:text-text")}
          >
            {t(label)}
          </button>
        ))}
      </div>
      {tab === "payments" ? <PaymentsTab /> : <CoinLedgerTab />}
    </>
  );
}

function PaymentsTab() {
  const t = useT();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [method, setMethod] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { items, meta, loading, error, reload, setItems } = useList<Payment>("/admin/payments", { q, status, method, page });
  const methods = asArray<PaymentMethod>(useApi<unknown>("/admin/payment-methods").data);
  const [openId, setOpenId] = useState<number | null>(null);

  return (
    <>
      <Toolbar>
        <SearchBox value={search} onChange={(v) => (setSearch(v), setPage(1))} placeholder="Reference, name, phone…" />
        <Select className="sm:w-40" value={status} onChange={(e) => (setStatus(e.target.value), setPage(1))} aria-label={t("Filter by status")}>
          <option value="">{t("All statuses")}</option>
          <option value="pending">{t("Pending")}</option>
          <option value="success">{t("Success")}</option>
          <option value="failed">{t("Failed")}</option>
          <option value="cancelled">{t("Cancelled")}</option>
          <option value="refunded">{t("Refunded")}</option>
        </Select>
        <Select className="sm:w-44" value={method} onChange={(e) => (setMethod(e.target.value), setPage(1))} aria-label={t("Filter by method")}>
          <option value="">{t("All methods")}</option>
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
            onRowClick={(p) => setOpenId(p.id)}
            columns={[
              { key: "ref", header: "Reference", render: (p) => <span className="font-mono text-xs">{p.reference}</span> },
              {
                key: "user",
                header: "User",
                render: (p) => (
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{p.user?.name ?? "-"}</p>
                    <p className="truncate text-xs text-text-dim">{p.phone ?? p.user?.email ?? p.user?.phone ?? ""}</p>
                  </div>
                ),
              },
              { key: "plan", header: "Package", render: (p) => p.plan?.name ?? "-" },
              { key: "method", header: "Method", render: (p) => methodLabel(p) },
              {
                key: "amount",
                header: "Amount",
                render: (p) => (
                  <div>
                    <span className="font-semibold">{formatMoney(p.amount, p.currency)}</span>
                    {!!p.refunded_amount && <p className="text-[11px] text-danger">−{formatMoney(p.refunded_amount, p.currency)}</p>}
                  </div>
                ),
              },
              { key: "status", header: "Status", render: (p) => <StatusPill status={p.status} /> },
              { key: "date", header: "Date", render: (p) => formatDate(p.paid_at ?? p.created_at, true) },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
      {openId !== null && (
        <PaymentDrawer
          id={openId}
          onClose={() => setOpenId(null)}
          onChanged={(p) => setItems((l) => l.map((x) => (x.id === p.id ? { ...x, ...p } : x)))}
        />
      )}
    </>
  );
}

function PaymentDrawer({ id, onClose, onChanged }: { id: number; onClose: () => void; onChanged: (p: Payment) => void }) {
  const t = useT();
  const { data, loading, mutate } = useApi<PaymentDetail>(`/admin/payments/${id}`);
  const [refunding, setRefunding] = useState(false);
  const [form, setForm] = useState({ amount: "", reason: "" });
  const [busy, setBusy] = useState(false);
  const p = data?.payment;
  const refundable = p ? p.amount - (p.refunded_amount ?? 0) : 0;

  const refund = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      const res = await api.post<PaymentDetail>(`/admin/payments/${id}/refund`, { amount: form.amount ? Number(form.amount) : null, reason: form.reason });
      mutate(() => res);
      onChanged(res.payment);
      toast.success(t("Refund recorded"));
      setRefunding(false);
      setForm({ amount: "", reason: "" });
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const row = (label: string, value: React.ReactNode) => (
    <>
      <dt className="text-text-dim">{t(label)}</dt>
      <dd className="text-right font-semibold">{value}</dd>
    </>
  );

  return (
    <Modal open onClose={onClose} title={p?.reference ?? t("Payment")} size="lg">
      {loading || !data || !p ? (
        <Skeleton className="h-64" />
      ) : (
        <div className="flex flex-col gap-4 text-sm">
          <div className="flex flex-wrap items-center gap-2">
            <StatusPill status={p.status} />
            {p.receipt_number && <Pill>{p.receipt_number}</Pill>}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Card title="Amounts">
              <dl className="grid grid-cols-2 gap-y-2">
                {row("Gross", formatMoney(p.amount, p.currency))}
                {row("Provider fee", formatMoney(p.fee_amount ?? 0, p.currency))}
                {row("Refunded", formatMoney(p.refunded_amount ?? 0, p.currency))}
                {row("Net", formatMoney(data.net_amount, p.currency))}
              </dl>
            </Card>
            <Card title="Payment">
              <dl className="grid grid-cols-2 gap-y-2">
                {row("Customer", p.user?.name ?? "-")}
                {row("Phone", p.phone ?? p.user?.phone ?? "-")}
                {row("Method", methodLabel(p))}
                {row("Package", p.plan?.name ?? "-")}
                {row("Provider ref.", <span className="font-mono text-xs">{p.provider_reference ?? "-"}</span>)}
                {row("Paid", formatDate(p.paid_at, true))}
              </dl>
            </Card>
          </div>
          {data.receipt && (
            <Card title="Receipt">
              <p>
                {data.receipt.item.name} · <b>{data.receipt.item.delivered ?? "-"}</b>
              </p>
              <p className="text-xs text-text-dim">
                {data.receipt.receipt_number} · {formatDate(data.receipt.issued_at, true)} · {data.receipt.payment_method.name}
              </p>
            </Card>
          )}
          <Card title="Refunds">
            {data.refunds.length ? (
              <ul className="divide-y divide-border">
                {data.refunds.map((r) => (
                  <li key={r.id} className="flex items-center justify-between gap-3 py-2">
                    <div>
                      <p className="font-semibold">{formatMoney(r.amount, p.currency)}</p>
                      <p className="text-xs text-text-dim">
                        {r.reason} · {r.processed_by ?? ""} · {formatDate(r.created_at, true)}
                      </p>
                    </div>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-text-dim">{t("No refunds")}</p>
            )}
            {p.status === "success" && refundable > 0 && (
              <Button size="sm" variant="danger" className="mt-3" onClick={() => setRefunding(true)}>
                {t("Refund")}
              </Button>
            )}
          </Card>
          {refunding && (
            <form onSubmit={refund} className="grid gap-3 rounded-2xl border border-danger/30 p-4 sm:grid-cols-2">
              <Notice tone="warning" className="sm:col-span-2">
                {t("Send the money back through the provider's dashboard, then record it here. A full refund also removes the VIP, episode pack or unspent coins it bought.")}
              </Notice>
              <Field label="Amount (empty = full)" hint={t("Up to {amount}", { amount: formatMoney(refundable, p.currency) })}>
                <Input type="number" min={1} max={refundable} value={form.amount} onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))} />
              </Field>
              <Field label="Reason">
                <Input required value={form.reason} onChange={(e) => setForm((f) => ({ ...f, reason: e.target.value }))} />
              </Field>
              <div className="flex justify-end gap-2 sm:col-span-2">
                <Button type="button" variant="ghost" onClick={() => setRefunding(false)}>
                  {t("Cancel")}
                </Button>
                <Button type="submit" variant="danger" loading={busy}>
                  {t("Record refund")}
                </Button>
              </div>
            </form>
          )}
        </div>
      )}
    </Modal>
  );
}

function CoinLedgerTab() {
  const t = useT();
  const [type, setType] = useState("");
  const [userId, setUserId] = useState("");
  const [page, setPage] = useState(1);
  const uid = useDebounced(userId);
  const { items, meta, loading, error, reload } = useList<CoinTransaction & { user?: { name: string; email: string | null } }>("/admin/coin-transactions", {
    type,
    user_id: uid,
    page,
  });

  return (
    <>
      <Toolbar>
        <Input className="sm:w-40" inputMode="numeric" placeholder={t("User ID")} value={userId} onChange={(e) => (setUserId(e.target.value), setPage(1))} />
        <Select className="sm:w-48" value={type} onChange={(e) => (setType(e.target.value), setPage(1))} aria-label={t("Filter by type")}>
          <option value="">{t("All types")}</option>
          {(Object.keys(COIN_TYPE_LABEL) as CoinTransactionType[]).map((k) => (
            <option key={k} value={k}>
              {t(COIN_TYPE_LABEL[k])}
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
            rowKey={(c) => c.id}
            columns={[
              { key: "at", header: "Date", render: (c) => formatDate(c.created_at, true) },
              { key: "u", header: "User", render: (c) => <span>{c.user?.name ?? `#${c.user_id}`}</span> },
              { key: "t", header: "Type", render: (c) => <Pill>{t(COIN_TYPE_LABEL[c.type])}</Pill> },
              {
                key: "d",
                header: "Details",
                render: (c) => (
                  <span className="text-xs text-text-muted">{c.episode?.drama ? `${c.episode.drama.title} · EP ${c.episode.number}` : (c.description ?? "—")}</span>
                ),
              },
              {
                key: "a",
                header: "Coins",
                render: (c) => <span className={cn("font-bold", c.amount < 0 ? "text-danger" : "text-success")}>{c.amount > 0 ? `+${formatNumber(c.amount)}` : formatNumber(c.amount)}</span>,
              },
              { key: "b", header: "Balance", className: "text-right", render: (c) => formatNumber(c.balance_after) },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
    </>
  );
}
