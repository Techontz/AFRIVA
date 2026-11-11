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
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { useList } from "@/lib/hooks";
import type { PaymentMethod, PaymentMethodType } from "@/lib/types";

const GROUPS: { type: PaymentMethodType; icon: IconName }[] = [
  { type: "mobile_money", icon: "phone" },
  { type: "card", icon: "card" },
  { type: "bank", icon: "bank" },
];

type ConfigKey = "api_key" | "api_secret" | "shortcode" | "callback_url" | "public_key" | "secret_key" | "merchant_id" | "account_number";

const CONFIG_FIELDS: Record<PaymentMethodType, { key: ConfigKey; secret?: boolean }[]> = {
  mobile_money: [{ key: "api_key", secret: true }, { key: "api_secret", secret: true }, { key: "shortcode" }, { key: "callback_url" }],
  card: [{ key: "public_key" }, { key: "secret_key", secret: true }, { key: "merchant_id" }],
  bank: [{ key: "api_key", secret: true }, { key: "account_number" }, { key: "merchant_id" }],
};

export default function PaymentMethodsPage() {
  const { admin, common } = useT();
  const tr = admin.methods;
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
      toast.success(fmt(tr.configSaved, { name: configuring.name }));
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
        title={admin.nav.paymentMethods}
        description={tr.description}
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
                    <h2 className="text-[15px] font-bold">{tr.groups[g.type].title}</h2>
                    <p className="text-xs text-text-dim">{tr.groups[g.type].blurb}</p>
                  </div>
                </div>
                <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  {loading
                    ? Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-36 rounded-2xl" />)
                    : methods.map((m) => (
                        <div
                          key={m.id}
                          className="flex flex-col gap-4 rounded-2xl border border-border bg-surface p-4 transition-colors hover:border-text-dim/50"
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
                            {m.is_integrated ? <Pill tone="success">{tr.live}</Pill> : <Pill tone="gold">{tr.notConnected}</Pill>}
                          </div>
                          <div className="flex flex-col gap-2.5 text-sm">
                            <label className="flex items-center justify-between gap-3">
                              <span className="text-text-muted">{tr.enabledAtCheckout}</span>
                              <Toggle
                                size="sm"
                                label={fmt(tr.enableNamed, { name: m.name })}
                                checked={!!m.is_enabled}
                                onChange={(v) => update(m, { is_enabled: v }, fmt(v ? tr.enabled : tr.disabled, { name: m.name }))}
                              />
                            </label>
                            <label className="flex items-center justify-between gap-3">
                              <span className="text-text-muted">{tr.providerIntegrated}</span>
                              <Toggle
                                size="sm"
                                label={fmt(tr.integratedNamed, { name: m.name })}
                                checked={!!m.is_integrated}
                                onChange={(v) => update(m, { is_integrated: v }, fmt(v ? tr.markedIntegrated : tr.markedNotIntegrated, { name: m.name }))}
                              />
                            </label>
                          </div>
                          <Button size="sm" variant="secondary" onClick={() => openConfig(m)} className="self-start">
                            <Icon name="settings" size={15} /> {tr.configure}
                          </Button>
                        </div>
                      ))}
                </div>
              </section>
            );
          })}
          {!loading && !items.length && (
            <p className="text-sm text-text-muted">{tr.none}</p>
          )}
        </div>
      )}

      <Modal open={!!configuring} onClose={() => setConfiguring(null)} title={fmt(tr.configTitle, { name: configuring?.name ?? "" })}>
        {configuring && (
          <form onSubmit={saveConfig} className="flex flex-col gap-4">
            <div className="flex items-start gap-2 rounded-xl bg-surface-2 p-3 text-xs text-text-muted">
              <Icon name="shield" size={16} className="mt-0.5 shrink-0 text-success" />
              <p>
                {tr.keysNoteBefore}
                <code className="font-mono">MPESA_API_KEY</code>
                {tr.keysNoteAfter}
              </p>
            </div>
            {(CONFIG_FIELDS[configuring.type] ?? []).map((f) => (
              <Field key={f.key} label={tr.configFields[f.key]}>
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
                {common.actions.cancel}
              </Button>
              <Button type="submit" loading={saving}>
                {tr.saveKeys}
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </>
  );
}
