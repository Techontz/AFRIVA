"use client";

import { payoutText } from "@/components/admin/ApplicationReview";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { useLocale, useT } from "@/i18n/client";
import { api, asArray, errorMessage } from "@/lib/api";
import { formatDate, formatMoney } from "@/lib/format";
import { useApi, useList } from "@/lib/hooks";
import type { Company, Payout } from "@/lib/types";

export default function PayoutsPage() {
  const { admin, common, creator } = useT();
  const locale = useLocale();
  const tr = admin.payouts;
  const col = admin.cols;
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const { items, meta, loading, error, reload, setItems } = useList<Payout>("/admin/payouts", { status, page });
  const companies = asArray<Company>(useApi<unknown>("/admin/companies", { per_page: 100 }).data);

  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ company_id: "", amount: "", notes: "" });
  const [saving, setSaving] = useState(false);
  const [paying, setPaying] = useState<Payout | null>(null);
  const [reference, setReference] = useState("");

  const openCreate = () => {
    setForm({ company_id: companies[0] ? String(companies[0].id) : "", amount: "", notes: "" });
    setCreating(true);
  };

  const create = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post("/admin/payouts", {
        company_id: Number(form.company_id),
        amount: Number(form.amount),
        notes: form.notes || null,
      });
      toast.success(tr.recorded);
      setCreating(false);
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const openPay = (p: Payout) => {
    setReference(p.reference ?? "");
    setPaying(p);
  };

  const markPaid = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!paying) return;
    setSaving(true);
    try {
      const updated = await api.put<Payout>(`/admin/payouts/${paying.id}`, { status: "paid", reference: reference || null });
      setItems((list) =>
        list.map((p) =>
          p.id === paying.id
            ? { ...p, status: "paid", reference: reference || p.reference, paid_at: updated?.paid_at ?? new Date().toISOString() }
            : p,
        ),
      );
      toast.success(tr.markedPaid);
      setPaying(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <PageHeader
        title={admin.nav.payouts}
        description={tr.description}
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" size={18} /> {tr.record}
          </Button>
        }
      />
      <Toolbar>
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
          <option value="paid">{common.status.paid}</option>
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(p) => p.id}
            columns={[
              {
                key: "company",
                header: col.company,
                render: (p) => (
                  <div className="min-w-0">
                    <span className="font-semibold">{p.company?.name ?? companies.find((c) => c.id === p.company_id)?.name ?? "-"}</span>
                    {p.company?.payout?.method && <p className="truncate text-xs text-text-dim">{payoutText(p.company.payout, creator)}</p>}
                  </div>
                ),
              },
              { key: "amount", header: col.amount, render: (p) => <span className="font-semibold">{formatMoney(p.amount)}</span> },
              { key: "status", header: col.status, render: (p) => <StatusPill status={p.status} /> },
              { key: "ref", header: col.reference, render: (p) => <span className="font-mono text-xs">{p.reference ?? "-"}</span> },
              { key: "notes", header: tr.notes, render: (p) => <span className="line-clamp-1 max-w-[220px] text-text-muted">{p.notes ?? "-"}</span> },
              { key: "date", header: tr.createdPaid, render: (p) => `${formatDate(p.created_at, false, locale)}${p.paid_at ? ` · ${formatDate(p.paid_at, false, locale)}` : ""}` },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (p) =>
                  p.status === "pending" ? (
                    <Button size="sm" variant="secondary" onClick={() => openPay(p)}>
                      <Icon name="check" size={15} /> {tr.markPaid}
                    </Button>
                  ) : null,
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}

      <Modal open={creating} onClose={() => setCreating(false)} title={tr.record}>
        <form onSubmit={create} className="flex flex-col gap-4">
          <Field label={col.company}>
            <Select required value={form.company_id} onChange={(e) => setForm((f) => ({ ...f, company_id: e.target.value }))}>
              <option value="" disabled>
                {tr.selectCompany}
              </option>
              {companies.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label={tr.amountTzs}>
            <Input required type="number" min={1} value={form.amount} onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))} />
          </Field>
          <Field label={tr.notes}>
            <Textarea value={form.notes} onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))} placeholder={tr.notesPlaceholder} />
          </Field>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setCreating(false)}>
              {common.actions.cancel}
            </Button>
            <Button type="submit" loading={saving}>
              {tr.record}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal open={!!paying} onClose={() => setPaying(null)} title={tr.markPaidTitle} size="sm">
        <form onSubmit={markPaid} className="flex flex-col gap-4">
          <p className="text-sm text-text-muted">
            {formatMoney(paying?.amount)} {tr.to} <b className="text-text">{paying?.company?.name ?? tr.companyFallback}</b>
          </p>
          <Field label={tr.transferRef} hint={tr.transferRefHint}>
            <Input value={reference} onChange={(e) => setReference(e.target.value)} placeholder="TXN-…" />
          </Field>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setPaying(null)}>
              {common.actions.cancel}
            </Button>
            <Button type="submit" loading={saving}>
              {tr.confirmPaid}
            </Button>
          </div>
        </form>
      </Modal>
    </>
  );
}
