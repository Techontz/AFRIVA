"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { Card, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Feedback";
import { Field, Input, Toggle } from "@/components/ui/Form";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { useApi } from "@/lib/hooks";
import type { Settings } from "@/lib/types";

type KnownKey =
  | "platform_name"
  | "support_email"
  | "default_currency"
  | "coin_value_tzs"
  | "creator_revenue_share_percent"
  | "infra_monthly_budget_usd";

const KNOWN: { key: KnownKey; type?: string }[] = [
  { key: "platform_name" },
  { key: "support_email", type: "email" },
  { key: "default_currency" },
  { key: "coin_value_tzs", type: "number" },
  { key: "creator_revenue_share_percent", type: "number" },
  { key: "infra_monthly_budget_usd", type: "number" },
];

const SOCIAL = ["social_facebook", "social_youtube", "social_tiktok", "social_instagram"] as const;

const humanize = (k: string) => k.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase());

/** GET may return `{key: value}` or `[{key, value}]`. */
function normalize(raw: unknown): Settings {
  if (Array.isArray(raw)) {
    return Object.fromEntries(
      raw.map((r: { key?: string; value?: unknown }) => [String(r.key), (r.value ?? null) as Settings[string]]),
    );
  }
  return (raw ?? {}) as Settings;
}

export default function SettingsPage() {
  const { admin } = useT();
  const tr = admin.settings;
  const { data, loading, error, reload } = useApi<unknown>("/admin/settings");
  const [draft, setDraft] = useState<Settings>({});
  const [saving, setSaving] = useState(false);

  const server = normalize(data);
  const values: Settings = { ...server, ...draft };
  const extraKeys = Object.keys(server).filter((k) => !KNOWN.some((f) => f.key === k) && !(SOCIAL as readonly string[]).includes(k));

  const setVal = (k: string, v: Settings[string]) => setDraft((d) => ({ ...d, [k]: v }));
  const dirty = Object.keys(draft).length > 0;

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload: Settings = { ...values };
      if (payload.coin_value_tzs !== undefined && payload.coin_value_tzs !== null && payload.coin_value_tzs !== "")
        payload.coin_value_tzs = Number(payload.coin_value_tzs);
      if (payload.creator_revenue_share_percent !== undefined && payload.creator_revenue_share_percent !== null && payload.creator_revenue_share_percent !== "")
        payload.creator_revenue_share_percent = Number(payload.creator_revenue_share_percent);
      if (payload.infra_monthly_budget_usd === "") payload.infra_monthly_budget_usd = null;
      await api.put("/admin/settings", payload);
      toast.success(tr.saved);
      setDraft({});
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const renderField = (key: string, label: string, hint?: string, type?: string) => {
    const v = values[key];
    if (typeof v === "boolean") {
      return (
        <label key={key} className="flex items-center justify-between gap-3 rounded-xl border border-border px-4 py-3 text-sm">
          <span className="font-semibold">{label}</span>
          <Toggle checked={v} onChange={(nv) => setVal(key, nv)} label={label} />
        </label>
      );
    }
    return (
      <Field key={key} label={label} hint={hint}>
        <Input type={type ?? (typeof v === "number" ? "number" : "text")} value={v === null || v === undefined ? "" : String(v)} onChange={(e) => setVal(key, e.target.value)} />
      </Field>
    );
  };

  return (
    <>
      <PageHeader title={admin.nav.settings} description={tr.description} />
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <form onSubmit={save} className="flex max-w-3xl flex-col gap-4">
          <Card title={tr.general}>
            {loading ? (
              <div className="grid gap-4 sm:grid-cols-2">
                {KNOWN.map((f) => (
                  <Skeleton key={f.key} className="h-16" />
                ))}
              </div>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2">{KNOWN.map((f) =>
                  renderField(
                    f.key,
                    tr.fields[f.key].label,
                    f.key === "creator_revenue_share_percent"
                      ? fmt(tr.fields[f.key].hint, { platform: Math.round((100 - Number(values[f.key] ?? 60)) * 100) / 100 })
                      : tr.fields[f.key].hint || undefined,
                    f.type,
                  ),
                )}</div>
            )}
          </Card>
          <Card title={tr.social}>
            {loading ? (
              <div className="grid gap-4 sm:grid-cols-2">
                {SOCIAL.map((k) => (
                  <Skeleton key={k} className="h-16" />
                ))}
              </div>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2">{SOCIAL.map((k) => renderField(k, tr.fields[k].label, tr.fields[k].hint, "url"))}</div>
            )}
          </Card>
          {!loading && extraKeys.length > 0 && (
            <Card title={tr.other}>
              <div className="grid gap-4 sm:grid-cols-2">{extraKeys.map((k) => renderField(k, humanize(k)))}</div>
            </Card>
          )}
          <div className="flex justify-end gap-2">
            {dirty && (
              <Button type="button" variant="ghost" onClick={() => setDraft({})}>
                {tr.discard}
              </Button>
            )}
            <Button type="submit" loading={saving} disabled={loading}>
              {tr.save}
            </Button>
          </div>
        </form>
      )}
    </>
  );
}
