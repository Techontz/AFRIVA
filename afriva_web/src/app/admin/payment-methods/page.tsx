"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill, Skeleton } from "@/components/ui/Feedback";
import { Field, Input, Toggle } from "@/components/ui/Form";
import { Icon, type IconName } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { Notice } from "@/components/portal/ScopeKit";
import { formatDate } from "@/lib/format";
import { api, errorMessage } from "@/lib/api";
import { useList } from "@/lib/hooks";
import type { PaymentMethod, PaymentMethodType } from "@/lib/types";
import { useT } from "@/lib/i18n";

const GROUPS: { type: PaymentMethodType; title: string; icon: IconName; blurb: string }[] = [
  { type: "mobile_money", title: "Mobile money (Tanzania)", icon: "phone", blurb: "M-Pesa, Mixx by Yas, Airtel Money, HaloPesa: USSD push to the customer's phone" },
  { type: "card", title: "Cards and wallets (worldwide)", icon: "card", blurb: "Visa & Mastercard, and digital wallets where the provider supports them" },
  { type: "bank", title: "Bank", icon: "bank", blurb: "Not part of the launch; keep disabled until a provider is chosen" },
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
  const [confirming, setConfirming] = useState<PaymentMethod | null>(null);
  const [feeFor, setFeeFor] = useState<PaymentMethod | null>(null);
  const [fee, setFee] = useState("");
  const t = useT();

  const update = async (m: PaymentMethod, body: Partial<PaymentMethod>, msg?: string) => {
    setItems((list) => list.map((x) => (x.id === m.id ? { ...x, ...body } : x)));
    try {
      const saved = await api.put<PaymentMethod>(`/admin/payment-methods/${m.id}`, body);
      if (saved) setItems((list) => list.map((x) => (x.id === m.id ? { ...x, ...saved } : x)));
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
      toast.success(t("{name} configuration saved", { name: configuring.name }));
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
        description="Choose which methods appear at checkout. Viewers only see a method as payable once it is connected to a tested provider."
      />
      <Notice tone="warning" className="mb-6" title="Only mark a provider as connected after a successful live test">
        {t("Until then the method shows as \"coming soon\" and checkout refuses it. Coins/VIP are only delivered after the provider confirms the payment to the server.")}
      </Notice>

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
                    <h2 className="text-[15px] font-bold">{t(g.title)}</h2>
                    <p className="text-xs text-text-dim">{t(g.blurb)}</p>
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
                            {m.is_integrated ? <Pill tone="success">{t("Connected")}</Pill> : <Pill tone="gold">{t("Not connected")}</Pill>}
                          </div>
                          <div className="flex flex-col gap-2.5 text-sm">
                            <label className="flex items-center justify-between gap-3">
                              <span className="text-text-muted">{t("Enabled at checkout")}</span>
                              <Toggle
                                size="sm"
                                label={t("Enable {name}", { name: m.name })}
                                checked={!!m.is_enabled}
                                onChange={(v) => update(m, { is_enabled: v }, v ? t("{name} enabled", { name: m.name }) : t("{name} disabled", { name: m.name }))}
                              />
                            </label>
                            <label className="flex items-center justify-between gap-3">
                              <span className="text-text-muted">{t("Provider integrated")}</span>
                              <Toggle
                                size="sm"
                                label={t("{name} integrated", { name: m.name })}
                                checked={!!m.is_integrated}
                                onChange={(v) =>
                                  v ? setConfirming(m) : update(m, { is_integrated: false }, t("{name} marked not integrated", { name: m.name }))
                                }
                              />
                            </label>
                            <div className="flex items-center justify-between gap-3 text-xs">
                              <span className="text-text-dim">
                                {m.tested_at ? t("Tested {date}", { date: formatDate(m.tested_at) }) : t("Not tested")}
                              </span>
                              <button
                                type="button"
                                className="font-semibold text-text-muted hover:text-text"
                                onClick={() => {
                                  setFeeFor(m);
                                  setFee(String(m.fee_percent ?? 0));
                                }}
                              >
                                {t("Fee {n}%", { n: m.fee_percent ?? 0 })} <Icon name="edit" size={12} className="inline" />
                              </button>
                            </div>
                            {m.is_enabled && !m.is_available && (
                              <p className="text-[11px] text-amber-300">{t("Shown to viewers as coming soon")}</p>
                            )}
                          </div>
                          <Button size="sm" variant="secondary" onClick={() => openConfig(m)} className="self-start">
                            <Icon name="settings" size={15} /> {t("Configure keys")}
                          </Button>
                        </div>
                      ))}
                </div>
              </section>
            );
          })}
          {!loading && !items.length && (
            <p className="text-sm text-text-muted">{t("No payment methods returned by the API.")}</p>
          )}
        </div>
      )}

      <ConfirmModal
        open={!!confirming}
        onClose={() => setConfirming(null)}
        onConfirm={() => {
          if (confirming) update(confirming, { is_integrated: true }, t("{name} marked integrated", { name: confirming.name }));
          setConfirming(null);
        }}
        title="Mark as connected?"
        message="Confirm that a real payment with this provider was completed and confirmed by the server callback. Viewers will be able to pay with it immediately."
        confirmLabel="Yes, it was tested"
      />
      <Modal open={!!feeFor} onClose={() => setFeeFor(null)} title={t("{name} fee", { name: feeFor?.name ?? "" })} size="sm">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (feeFor) update(feeFor, { fee_percent: Number(fee || 0) }, t("Fee saved"));
            setFeeFor(null);
          }}
          className="flex flex-col gap-4"
        >
          <Field label="Provider fee (%)" hint="Used to separate fees from net revenue in Analytics">
            <Input type="number" min={0} max={50} step="0.01" value={fee} onChange={(e) => setFee(e.target.value)} />
          </Field>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setFeeFor(null)}>
              {t("Cancel")}
            </Button>
            <Button type="submit">{t("Save")}</Button>
          </div>
        </form>
      </Modal>

      <Modal open={!!configuring} onClose={() => setConfiguring(null)} title={t("{name} configuration", { name: configuring?.name ?? "" })}>
        {configuring && (
          <form onSubmit={saveConfig} className="flex flex-col gap-4">
            <div className="flex items-start gap-2 rounded-xl bg-surface-2 p-3 text-xs text-text-muted">
              <Icon name="shield" size={16} className="mt-0.5 shrink-0 text-success" />
              <p>
                {t("Keys are stored encrypted on the server. Leave a field blank to keep its current value. Environment variables")}{" "}
                ({t("e.g.")} <code className="font-mono">MPESA_API_KEY</code>) {t("take effect when the gateway driver is integrated.")}
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
                {t("Cancel")}
              </Button>
              <Button type="submit" loading={saving}>
                {t("Save keys")}
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </>
  );
}
