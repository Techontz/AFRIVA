"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { Card, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Feedback";
import { Field, Input, Textarea, Toggle } from "@/components/ui/Form";
import { api, errorMessage } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { useApi } from "@/lib/hooks";
import type { Settings } from "@/lib/types";

type Known = { key: string; label: string; hint?: string; type?: string; textarea?: boolean };

const GROUPS: { title: string; fields: Known[] }[] = [
  {
    title: "General",
    fields: [
      { key: "platform_name", label: "Platform name" },
      { key: "support_email", label: "Support email", type: "email" },
      { key: "default_currency", label: "Default currency", hint: "ISO code, e.g. TZS" },
      { key: "coin_value_tzs", label: "Coin value (TZS)", hint: "Used to value coin unlocks for creator earnings", type: "number" },
    ],
  },
  {
    title: "Publishing defaults",
    fields: [
      { key: "default_free_episodes", label: "Free episodes for new series", hint: "Episodes 1…N are a free preview (scope: 8)", type: "number" },
      { key: "default_coins_per_episode", label: "Coins per locked episode", type: "number" },
    ],
  },
  {
    title: "Streaming costs and alerts",
    fields: [
      { key: "streaming_avg_kbps", label: "Average streamed bitrate (kbps)", hint: "Used to estimate data delivered from watch time", type: "number" },
      { key: "streaming_cost_per_gb_tzs", label: "Streaming cost per GB (TZS)", type: "number" },
      { key: "cost_alert_monthly_tzs", label: "Monthly cost alert (TZS)", hint: "Warn at 80% of this; 0 = off", type: "number" },
    ],
  },
  {
    title: "Creator revenue agreement",
    fields: [
      { key: "creator_agreement_version", label: "Agreement version", hint: "Changing it asks every creator to accept again" },
      { key: "creator_agreement_text", label: "Agreement text", textarea: true },
    ],
  },
];
const KNOWN: Known[] = GROUPS.flatMap((g) => g.fields);
const NUMERIC = KNOWN.filter((f) => f.type === "number").map((f) => f.key);

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
  const { data, loading, error, reload } = useApi<unknown>("/admin/settings");
  const [draft, setDraft] = useState<Settings>({});
  const [saving, setSaving] = useState(false);
  const t = useT();

  const server = normalize(data);
  const values: Settings = { ...server, ...draft };
  const extraKeys = Object.keys(server).filter((k) => !KNOWN.some((f) => f.key === k));

  const setVal = (k: string, v: Settings[string]) => setDraft((d) => ({ ...d, [k]: v }));
  const dirty = Object.keys(draft).length > 0;

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload: Settings = { ...values };
      for (const k of NUMERIC) {
        if (payload[k] !== undefined && payload[k] !== null && payload[k] !== "") payload[k] = Number(payload[k]);
      }
      await api.put("/admin/settings", payload);
      toast.success(t("Settings saved"));
      setDraft({});
      reload();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const renderField = (key: string, label: string, hint?: string, type?: string, textarea?: boolean) => {
    const v = values[key];
    if (textarea) {
      return (
        <Field key={key} label={label} hint={hint} className="sm:col-span-2">
          <Textarea rows={10} value={v === null || v === undefined ? "" : String(v)} onChange={(e) => setVal(key, e.target.value)} />
        </Field>
      );
    }
    if (typeof v === "boolean") {
      return (
        <label key={key} className="flex items-center justify-between gap-3 rounded-xl border border-border px-4 py-3 text-sm">
          <span className="font-semibold">{t(label)}</span>
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
      <PageHeader title="Settings" description="Platform-wide configuration." />
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <form onSubmit={save} className="flex max-w-3xl flex-col gap-4">
          {GROUPS.map((g) => (
            <Card key={g.title} title={g.title}>
              {loading ? (
                <div className="grid gap-4 sm:grid-cols-2">
                  {g.fields.map((f) => (
                    <Skeleton key={f.key} className="h-16" />
                  ))}
                </div>
              ) : (
                <div className="grid gap-4 sm:grid-cols-2">{g.fields.map((f) => renderField(f.key, f.label, f.hint, f.type, f.textarea))}</div>
              )}
            </Card>
          ))}
          {!loading && extraKeys.length > 0 && (
            <Card title="Other settings">
              <div className="grid gap-4 sm:grid-cols-2">{extraKeys.map((k) => renderField(k, humanize(k)))}</div>
            </Card>
          )}
          <div className="flex justify-end gap-2">
            {dirty && (
              <Button type="button" variant="ghost" onClick={() => setDraft({})}>
                {t("Discard")}
              </Button>
            )}
            <Button type="submit" loading={saving} disabled={loading}>
              {t("Save settings")}
            </Button>
          </div>
        </form>
      )}
    </>
  );
}
