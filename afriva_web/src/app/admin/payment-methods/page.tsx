"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill, Skeleton } from "@/components/ui/Feedback";
import { Field, Input, Toggle } from "@/components/ui/Form";
import { Icon, type IconName } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { useList } from "@/lib/hooks";
import type { PaymentMethod, PaymentMethodType } from "@/lib/types";

const GROUPS: { type: PaymentMethodType; title: string; icon: IconName; blurb: string }[] = [
  { type: "mobile_money", title: "Mobile Money", icon: "phone", blurb: "USSD push to the customer's handset" },
  { type: "card", title: "Cards", icon: "card", blurb: "Visa & Mastercard via a card processor" },
  { type: "bank", title: "Bank", icon: "bank", blurb: "Bank transfer / internet banking" },
];

const CONFIG_FIELDS: Record<PaymentMethodType, { key: string; label: string; secret?: boolean }[]> = {
  mobile_money: [
    { key: "api_key", label: "API key", secret: true },
    { key: "api_secret", label: "API secret", secret: true },
    { key: "shortcode", label: "Shortcode / merchant number" },
    { key: "callback_url", label: "Callback URL" },
  ],
  card: [
    { key: "public_key", label: "Public key" },
    { key: "secret_key", label: "Secret key", secret: true },
    { key: "merchant_id", label: "Merchant ID" },
  ],
  bank: [
    { key: "api_key", label: "API key", secret: true },
    { key: "account_number", label: "Settlement account number" },
    { key: "merchant_id", label: "Merchant ID" },
  ],
};

export default function PaymentMethodsPage() {
  const { items, loading, error, reload, setItems } = useList<PaymentMethod>("/admin/payment-methods");
  const [configuring, setConfiguring] = useState<PaymentMethod | null>(null);
  const [config, setConfig] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  const update = async (m: PaymentMethod, body: Partial<PaymentMethod>, msg?: string) => {
    setItems((list) => list.map((x) => (x.id === m.id ? { ...x, ...body } : x)));
    try {
      await api.put(`/admin/payment-methods/${m.id}`, body);
      if (msg) toast.success(msg);
    } catch (err) {
      setItems((list) => list.map((x) => (x.id === m.id ? m : x)));
      toast.error(errorMessage(err));
    }
  };

  const openConfig = (m: PaymentMethod) => {
    const c: Record<string, string> = {};
    for (const f of CONFIG_FIELDS[m.type] ?? []) c[f.key] = m.config?.[f.key] ?? "";
    setConfig(c);
    setConfiguring(m);
  };

  const saveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!configuring) return;
    setSaving(true);
    // Only send fields the admin filled, so masked/blank values don't wipe stored secrets.
    const payload = Object.fromEntries(Object.entries(config).filter(([, v]) => v.trim() !== ""));
    try {
      await api.put(`/admin/payment-methods/${configuring.id}`, { config: payload });
      setItems((list) => list.map((x) => (x.id === configuring.id ? { ...x, config: { ...(x.config ?? {}), ...payload } } : x)));
      toast.success(`${configuring.name} configuration saved`);
      setConfiguring(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Payment Methods"
        description="Choose which methods appear at checkout. Non-integrated methods create pending payments until a provider is connected."
      />

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <div className="flex flex-col gap-6">
          {GROUPS.map((g) => {
            const methods = items.filter((m) => m.type === g.type).sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
            if (!loading && !methods.length) return null;
            return (
              <section key={g.type}>
                <div className="mb-3 flex items-center gap-3">
                  <span className="grid h-9 w-9 place-items-center rounded-xl bg-surface-2 text-text-muted">
                    <Icon name={g.icon} size={18} />
                  </span>
                  <div>
                    <h2 className="text-[15px] font-bold">{g.title}</h2>
                    <p className="text-xs text-text-dim">{g.blurb}</p>
                  </div>
                </div>
                <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  {loading
                    ? Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-36 rounded-2xl" />)
                    : methods.map((m) => (
                        <div
                          key={m.id}
                          className="flex flex-col gap-4 rounded-2xl border border-border bg-surface p-4 transition-colors hover:border-[#3A3A3A]"
                        >
                          <div className="flex items-center gap-3">
                            <span
                              className="grid h-11 w-11 shrink-0 place-items-center overflow-hidden rounded-xl text-sm font-extrabold text-white"
                              style={{ background: m.color || "#262626" }}
                            >
                              {m.logo_url ? (
                                // eslint-disable-next-line @next/next/no-img-element
                                <img src={m.logo_url} alt="" className="h-full w-full object-contain p-1" />
                              ) : (
                                m.name.slice(0, 2).toUpperCase()
                              )}
                            </span>
                            <div className="min-w-0 flex-1">
                              <p className="truncate font-bold">{m.name}</p>
                              <p className="font-mono text-[11px] text-text-dim">{m.code}</p>
                            </div>
                            {m.is_integrated ? <Pill tone="success">Live</Pill> : <Pill tone="gold">Not connected</Pill>}
                          </div>
                          <div className="flex flex-col gap-2.5 text-sm">
                            <label className="flex items-center justify-between gap-3">
                              <span className="text-text-muted">Enabled at checkout</span>
                              <Toggle
                                size="sm"
                                label={`Enable ${m.name}`}
                                checked={!!m.is_enabled}
                                onChange={(v) => update(m, { is_enabled: v }, v ? `${m.name} enabled` : `${m.name} disabled`)}
                              />
                            </label>
                            <label className="flex items-center justify-between gap-3">
                              <span className="text-text-muted">Provider integrated</span>
                              <Toggle
                                size="sm"
                                label={`${m.name} integrated`}
                                checked={!!m.is_integrated}
                                onChange={(v) => update(m, { is_integrated: v }, v ? `${m.name} marked integrated` : `${m.name} marked not integrated`)}
                              />
                            </label>
                          </div>
                          <Button size="sm" variant="secondary" onClick={() => openConfig(m)} className="self-start">
                            <Icon name="settings" size={15} /> Configure keys
                          </Button>
                        </div>
                      ))}
                </div>
              </section>
            );
          })}
          {!loading && !items.length && (
            <p className="text-sm text-text-muted">No payment methods returned by the API.</p>
          )}
        </div>
      )}

      <Modal open={!!configuring} onClose={() => setConfiguring(null)} title={`${configuring?.name ?? ""} configuration`}>
        {configuring && (
          <form onSubmit={saveConfig} className="flex flex-col gap-4">
            <div className="flex items-start gap-2 rounded-xl bg-surface-2 p-3 text-xs text-text-muted">
              <Icon name="shield" size={16} className="mt-0.5 shrink-0 text-success" />
              <p>
                Keys are stored encrypted on the server. Leave a field blank to keep its current value. Environment variables
                (e.g. <code className="font-mono">MPESA_API_KEY</code>) take effect when the gateway driver is integrated.
              </p>
            </div>
            {(CONFIG_FIELDS[configuring.type] ?? []).map((f) => (
              <Field key={f.key} label={f.label}>
                <Input
                  type={f.secret ? "password" : "text"}
                  autoComplete="off"
                  value={config[f.key] ?? ""}
                  onChange={(e) => setConfig((c) => ({ ...c, [f.key]: e.target.value }))}
                  placeholder={f.secret ? "••••••••" : ""}
                />
              </Field>
            ))}
            <div className="flex justify-end gap-2">
              <Button type="button" variant="ghost" onClick={() => setConfiguring(null)}>
                Cancel
              </Button>
              <Button type="submit" loading={saving}>
                Save keys
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </>
  );
}
