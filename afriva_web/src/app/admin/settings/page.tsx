"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { Card, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Feedback";
import { Field, Input, Toggle } from "@/components/ui/Form";
import { api, errorMessage } from "@/lib/api";
import { useApi } from "@/lib/hooks";
import type { Settings } from "@/lib/types";

const KNOWN: { key: string; label: string; hint?: string; type?: string }[] = [
  { key: "platform_name", label: "Platform name" },
  { key: "support_email", label: "Support email", type: "email" },
  { key: "default_currency", label: "Default currency", hint: "ISO code, e.g. TZS" },
  { key: "coin_value_tzs", label: "Coin value (TZS)", hint: "Used to value coin unlocks for company earnings", type: "number" },
];

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
      if (payload.coin_value_tzs !== undefined && payload.coin_value_tzs !== null && payload.coin_value_tzs !== "")
        payload.coin_value_tzs = Number(payload.coin_value_tzs);
      await api.put("/admin/settings", payload);
      toast.success("Settings saved");
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
      <PageHeader title="Settings" description="Platform-wide configuration." />
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <form onSubmit={save} className="flex max-w-3xl flex-col gap-4">
          <Card title="General">
            {loading ? (
              <div className="grid gap-4 sm:grid-cols-2">
                {KNOWN.map((f) => (
                  <Skeleton key={f.key} className="h-16" />
                ))}
              </div>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2">{KNOWN.map((f) => renderField(f.key, f.label, f.hint, f.type))}</div>
            )}
          </Card>
          {!loading && extraKeys.length > 0 && (
            <Card title="Other settings">
              <div className="grid gap-4 sm:grid-cols-2">{extraKeys.map((k) => renderField(k, humanize(k)))}</div>
            </Card>
          )}
          <div className="flex justify-end gap-2">
            {dirty && (
              <Button type="button" variant="ghost" onClick={() => setDraft({})}>
                Discard
              </Button>
            )}
            <Button type="submit" loading={saving} disabled={loading}>
              Save settings
            </Button>
          </div>
        </form>
      )}
    </>
  );
}
