"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError, numOrNull, str } from "@/components/admin/helpers";
import { DataTable, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea, Toggle } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatMoney, planSummary } from "@/lib/format";
import { useList } from "@/lib/hooks";
import type { Plan, PlanType } from "@/lib/types";
import { useT } from "@/lib/i18n";

interface Form {
  name: string;
  type: PlanType;
  price: string;
  currency: string;
  duration_days: string;
  episode_quota: string;
  coins: string;
  bonus_coins: string;
  description: string;
  features: string;
  is_popular: boolean;
  is_active: boolean;
  sort_order: string;
}

const empty: Form = {
  name: "",
  type: "monthly",
  price: "",
  currency: "TZS",
  duration_days: "30",
  episode_quota: "",
  coins: "",
  bonus_coins: "",
  description: "",
  features: "",
  is_popular: false,
  is_active: true,
  sort_order: "0",
};

const DEFAULT_DAYS: Partial<Record<PlanType, string>> = { weekly: "7", monthly: "30", yearly: "365" };
const isTime = (t: PlanType) => t === "weekly" || t === "monthly" || t === "yearly";

const typeTone = { weekly: "info", monthly: "brand", yearly: "success", episodes: "neutral", coins: "gold" } as const;

export default function PlansPage() {
  const { items, loading, error, reload, setItems } = useList<Plan>("/admin/plans");
  const plans = [...items].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
  const [editing, setEditing] = useState<Plan | null>(null);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<Form>(empty);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Plan | null>(null);
  const [busy, setBusy] = useState(false);
  const t = useT();

  const set = (k: keyof Form) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }));

  const openCreate = () => {
    setEditing(null);
    setForm(empty);
    setOpen(true);
  };
  const openEdit = (p: Plan) => {
    setEditing(p);
    setForm({
      name: p.name,
      type: p.type,
      price: str(p.price),
      currency: p.currency || "TZS",
      duration_days: str(p.duration_days),
      episode_quota: str(p.episode_quota),
      coins: str(p.coins),
      bonus_coins: str(p.bonus_coins),
      description: str(p.description),
      features: (p.features ?? []).join("\n"),
      is_popular: !!p.is_popular,
      is_active: p.is_active !== false,
      sort_order: str(p.sort_order ?? 0),
    });
    setOpen(true);
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const type = form.type;
    const body = {
      name: form.name,
      type,
      price: Number(form.price || 0),
      currency: form.currency || "TZS",
      duration_days: isTime(type) ? numOrNull(form.duration_days) : null,
      episode_quota: type === "episodes" ? numOrNull(form.episode_quota) : null,
      coins: type === "coins" ? numOrNull(form.coins) : null,
      bonus_coins: type === "coins" ? numOrNull(form.bonus_coins) : null,
      description: form.description || null,
      features: form.features
        .split("\n")
        .map((s) => s.trim())
        .filter(Boolean),
      is_popular: form.is_popular,
      is_active: form.is_active,
      sort_order: Number(form.sort_order || 0),
    };
    try {
      if (editing) {
        await api.put(`/admin/plans/${editing.id}`, body);
        setItems((list) => list.map((p) => (p.id === editing.id ? ({ ...p, ...body } as Plan) : p)));
        toast.success(t("Plan updated"));
      } else {
        await api.post("/admin/plans", body);
        toast.success(t("Plan created"));
        reload();
      }
      setOpen(false);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (p: Plan, key: "is_active" | "is_popular", v: boolean) => {
    setItems((list) => list.map((x) => (x.id === p.id ? { ...x, [key]: v } : x)));
    try {
      await api.put(`/admin/plans/${p.id}`, { [key]: v });
    } catch (err) {
      setItems((list) => list.map((x) => (x.id === p.id ? p : x)));
      toast.error(errorMessage(err));
    }
  };

  const remove = async () => {
    if (!deleting) return;
    setBusy(true);
    try {
      await api.del(`/admin/plans/${deleting.id}`);
      setItems((list) => list.filter((x) => x.id !== deleting.id));
      toast.success(t("Plan deleted"));
      setDeleting(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Plans"
        description="VIP subscriptions, episode packs and coin packs sold on /vip and in the app."
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" size={18} /> {t("New plan")}
          </Button>
        }
      />
      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <DataTable
          loading={loading}
          rows={plans}
          rowKey={(p) => p.id}
          columns={[
            {
              key: "name",
              header: "Plan",
              render: (p) => (
                <div className="min-w-0">
                  <p className="flex items-center gap-2 font-semibold">
                    {p.name}
                    {p.is_popular && <Pill tone="brand">{t("Popular")}</Pill>}
                  </p>
                  <p className="truncate text-xs text-text-dim">{planSummary(p, t)}</p>
                </div>
              ),
            },
            { key: "type", header: "Type", render: (p) => <Pill tone={typeTone[p.type] ?? "neutral"}>{t(p.type)}</Pill> },
            { key: "price", header: "Price", render: (p) => <span className="font-semibold">{formatMoney(p.price, p.currency)}</span> },
            { key: "pop", header: "Popular", render: (p) => <Toggle size="sm" label="Popular" checked={!!p.is_popular} onChange={(v) => toggle(p, "is_popular", v)} /> },
            { key: "active", header: "Active", render: (p) => <Toggle size="sm" label="Active" checked={p.is_active !== false} onChange={(v) => toggle(p, "is_active", v)} /> },
            { key: "sort", header: "Order", render: (p) => p.sort_order ?? 0 },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (p) => (
                <div className="flex justify-end gap-1">
                  <Button size="sm" variant="ghost" onClick={() => openEdit(p)}>
                    {t("Edit")}
                  </Button>
                  <button
                    onClick={() => setDeleting(p)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                    aria-label={t("Delete {name}", { name: p.name })}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                </div>
              ),
            },
          ]}
        />
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={editing ? t("Edit {name}", { name: editing.name }) : "New plan"} size="lg">
        <form onSubmit={save} className="grid gap-4 sm:grid-cols-2">
          <Field label="Name" className="sm:col-span-2">
            <Input required value={form.name} onChange={set("name")} placeholder={t("Monthly VIP")} />
          </Field>
          <Field label="Type">
            <Select
              value={form.type}
              onChange={(e) => {
                const type = e.target.value as PlanType;
                setForm((f) => ({ ...f, type, duration_days: DEFAULT_DAYS[type] ?? f.duration_days }));
              }}
            >
              <option value="weekly">{t("Weekly VIP")}</option>
              <option value="monthly">{t("Monthly VIP")}</option>
              <option value="yearly">{t("Yearly VIP")}</option>
              <option value="episodes">{t("Episode pack")}</option>
              <option value="coins">{t("Coin pack")}</option>
            </Select>
          </Field>
          <div className="grid grid-cols-[1fr_96px] gap-2">
            <Field label="Price">
              <Input required type="number" min={0} value={form.price} onChange={set("price")} />
            </Field>
            <Field label="Currency">
              <Input value={form.currency} onChange={set("currency")} maxLength={3} />
            </Field>
          </div>
          {isTime(form.type) && (
            <Field label="Duration (days)">
              <Input required type="number" min={1} value={form.duration_days} onChange={set("duration_days")} />
            </Field>
          )}
          {form.type === "episodes" && (
            <Field label="Episode quota" hint="Episodes the buyer can unlock">
              <Input required type="number" min={1} value={form.episode_quota} onChange={set("episode_quota")} />
            </Field>
          )}
          {form.type === "coins" && (
            <>
              <Field label="Coins">
                <Input required type="number" min={1} value={form.coins} onChange={set("coins")} />
              </Field>
              <Field label="Bonus coins">
                <Input type="number" min={0} value={form.bonus_coins} onChange={set("bonus_coins")} />
              </Field>
            </>
          )}
          <Field label="Sort order">
            <Input type="number" value={form.sort_order} onChange={set("sort_order")} />
          </Field>
          <Field label="Description" className="sm:col-span-2">
            <Input value={form.description} onChange={set("description")} placeholder={t("Unlimited access to every drama")} />
          </Field>
          <Field label="Features" hint="One per line" className="sm:col-span-2">
            <Textarea value={form.features} onChange={set("features")} rows={4} placeholder={t("All episodes unlocked\nHD streaming\nNo ads")} />
          </Field>
          <div className="flex flex-wrap gap-6 sm:col-span-2">
            <label className="flex items-center gap-3 text-sm font-semibold">
              <Toggle checked={form.is_popular} onChange={(v) => setForm((f) => ({ ...f, is_popular: v }))} label="Popular" />
              {t("Mark as popular")}
            </label>
            <label className="flex items-center gap-3 text-sm font-semibold">
              <Toggle checked={form.is_active} onChange={(v) => setForm((f) => ({ ...f, is_active: v }))} label="Active" />
              {t("Active")}
            </label>
          </div>
          <div className="flex justify-end gap-2 sm:col-span-2">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={saving}>
              {editing ? t("Save changes") : t("Create plan")}
            </Button>
          </div>
        </form>
      </Modal>

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title="Delete plan?"
        message={
          <>
            <b className="text-text">{deleting?.name}</b> {t("will no longer be purchasable. Existing subscriptions are unaffected.")}
          </>
        }
        confirmLabel="Delete"
      />
    </>
  );
}
