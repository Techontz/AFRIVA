"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, asArray, errorMessage } from "@/lib/api";
import { formatDate, formatMoney } from "@/lib/format";
import { useApi, useList } from "@/lib/hooks";
import type { Company, Payout } from "@/lib/types";
import { useT } from "@/lib/i18n";

export default function PayoutsPage() {
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const { items, meta, loading, error, reload, setItems } = useList<Payout>("/admin/payouts", { status, page });
  const companies = asArray<Company>(useApi<unknown>("/admin/companies", { per_page: 100 }).data);

  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ company_id: "", amount: "", notes: "" });
  const [saving, setSaving] = useState(false);
  const [paying, setPaying] = useState<Payout | null>(null);
  const [reference, setReference] = useState("");
  const t = useT();

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
      toast.success(t("Payout recorded"));
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
      toast.success(t("Payout marked as paid"));
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
        title="Payouts"
        description="Settlements of company earnings."
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" size={18} /> {t("Record payout")}
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
          aria-label={t("Filter by status")}
        >
          <option value="">{t("All statuses")}</option>
          <option value="pending">{t("Pending")}</option>
          <option value="paid">{t("Paid")}</option>
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
                header: "Company",
                render: (p) => <span className="font-semibold">{p.company?.name ?? companies.find((c) => c.id === p.company_id)?.name ?? "-"}</span>,
              },
              { key: "amount", header: "Amount", render: (p) => <span className="font-semibold">{formatMoney(p.amount)}</span> },
              { key: "status", header: "Status", render: (p) => <StatusPill status={p.status} /> },
              { key: "ref", header: "Reference", render: (p) => <span className="font-mono text-xs">{p.reference ?? "-"}</span> },
              { key: "notes", header: "Notes", render: (p) => <span className="line-clamp-1 max-w-[220px] text-text-muted">{p.notes ?? "-"}</span> },
              { key: "date", header: "Created / Paid", render: (p) => `${formatDate(p.created_at)}${p.paid_at ? ` · ${formatDate(p.paid_at)}` : ""}` },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (p) =>
                  p.status === "pending" ? (
                    <Button size="sm" variant="secondary" onClick={() => openPay(p)}>
                      <Icon name="check" size={15} /> {t("Mark paid")}
                    </Button>
                  ) : null,
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}

      <Modal open={creating} onClose={() => setCreating(false)} title="Record payout">
        <form onSubmit={create} className="flex flex-col gap-4">
          <Field label="Company">
            <Select required value={form.company_id} onChange={(e) => setForm((f) => ({ ...f, company_id: e.target.value }))}>
              <option value="" disabled>
                {t("Select a company")}
              </option>
              {companies.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Amount (TZS)">
            <Input required type="number" min={1} value={form.amount} onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))} />
          </Field>
          <Field label="Notes">
            <Textarea value={form.notes} onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))} placeholder={t("e.g. October earnings settlement")} />
          </Field>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setCreating(false)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={saving}>
              {t("Record payout")}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal open={!!paying} onClose={() => setPaying(null)} title="Mark payout as paid" size="sm">
        <form onSubmit={markPaid} className="flex flex-col gap-4">
          <p className="text-sm text-text-muted">
            {formatMoney(paying?.amount)} {t("to")} <b className="text-text">{paying?.company?.name ?? t("company")}</b>
          </p>
          <Field label="Transfer reference" hint="Bank or mobile money transaction ID">
            <Input value={reference} onChange={(e) => setReference(e.target.value)} placeholder="TXN-…" />
          </Field>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setPaying(null)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={saving}>
              {t("Confirm paid")}
            </Button>
          </div>
        </form>
      </Modal>
    </>
  );
}
