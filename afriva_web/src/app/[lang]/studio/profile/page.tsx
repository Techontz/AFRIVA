"use client";

import { useState, type FormEvent } from "react";
import { toast } from "sonner";
import { Card, PageHeader } from "@/components/portal/Kit";
import { appendMedia, MediaInput, type MediaValue } from "@/components/portal/MediaInput";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Skeleton, StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea } from "@/components/ui/Form";
import { useT } from "@/i18n/client";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useApi } from "@/lib/hooks";
import { PAYOUT_PROVIDERS } from "@/lib/creator";
import type { Company } from "@/lib/types";

const COUNTRIES = ["TZ", "KE", "UG", "RW", "NG", "GH", "ZA", "ET", "Other"];

function ProfileForm({ company, onSaved }: { company: Company; onSaved: (c: Company) => void }) {
  const t = useT().studio.profile;
  const [f, setF] = useState({
    name: company.name ?? "",
    email: company.email ?? "",
    phone: company.phone ?? "",
    country: company.country ?? "TZ",
    description: company.description ?? "",
    payout_method: company.payout?.method ?? "",
    payout_provider: company.payout?.provider ?? "mpesa",
    payout_bank_name: company.payout?.bank_name ?? "",
    payout_account_name: company.payout?.account_name ?? "",
    payout_account_number: company.payout?.account_number ?? "",
  });
  const c = useT().creator;
  const [logo, setLogo] = useState<MediaValue>({ url: company.logo_url ?? "", file: null });
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  const err = (k: string) => errors[k]?.[0] ?? null;
  const set = (k: keyof typeof f, v: string) => setF((s) => ({ ...s, [k]: v }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setErrors({});
    let body: FormData | Record<string, unknown>;
    // Payout fields only when a method is chosen, and only those that belong to it.
    const { payout_method, payout_provider, payout_bank_name, payout_account_name, payout_account_number, ...details } = f;
    const fields: Record<string, string> = payout_method
      ? {
          ...details,
          payout_method,
          payout_account_name,
          payout_account_number,
          ...(payout_method === "bank" ? { payout_bank_name } : { payout_provider }),
        }
      : details;
    if (logo.file) {
      const fd = new FormData();
      Object.entries(fields).forEach(([k, v]) => fd.append(k, v));
      appendMedia(fd, "logo", logo);
      body = fd;
    } else {
      body = { ...fields, logo_url: logo.url || null };
    }
    try {
      const saved = unwrapCompany(await api.put<Company>("/studio/profile", body));
      toast.success(t.updated);
      if (saved) onSaved(saved);
    } catch (e) {
      if (e instanceof ApiError && e.errors) setErrors(e.errors);
      toast.error(errorMessage(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={submit} className="grid gap-4 lg:grid-cols-[1fr_300px]">
      <div className="space-y-4">
      <Card title={t.details}>
        <div className="grid gap-4">
          <Field label={t.name} htmlFor="name" error={err("name")}>
            <Input id="name" required value={f.name} onChange={(e) => set("name", e.target.value)} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t.email} htmlFor="email" error={err("email")}>
              <Input id="email" type="email" value={f.email} onChange={(e) => set("email", e.target.value)} />
            </Field>
            <Field label={t.phone} htmlFor="phone" error={err("phone")}>
              <Input id="phone" type="tel" value={f.phone} onChange={(e) => set("phone", e.target.value)} placeholder="+255 7xx xxx xxx" />
            </Field>
          </div>
          <Field label={t.country} htmlFor="country" error={err("country")}>
            <Select id="country" value={f.country} onChange={(e) => set("country", e.target.value)}>
              {[...new Set([f.country, ...COUNTRIES])].filter(Boolean).map((c) => (
                <option key={c} value={c}>
                  {c === "Other" ? t.other : c}
                </option>
              ))}
            </Select>
          </Field>
          <Field label={t.about} htmlFor="description" error={err("description")}>
            <Textarea id="description" rows={5} value={f.description} onChange={(e) => set("description", e.target.value)} />
          </Field>
        </div>
      </Card>
      <Card title={c.payout.title}>
        <div className="grid gap-4 sm:grid-cols-2">
          <p className="text-xs text-text-dim sm:col-span-2">{c.payout.hint}</p>
          <Field label={c.payout.method} htmlFor="payout_method" error={err("payout_method")}>
            <Select id="payout_method" value={f.payout_method} onChange={(e) => set("payout_method", e.target.value)}>
              <option value="">{c.payout.none}</option>
              <option value="mobile_money">{c.form.mobileMoney}</option>
              <option value="bank">{c.form.bank}</option>
            </Select>
          </Field>
          {f.payout_method === "bank" ? (
            <Field label={c.form.bankName} htmlFor="payout_bank_name" error={err("payout_bank_name")}>
              <Input id="payout_bank_name" value={f.payout_bank_name} onChange={(e) => set("payout_bank_name", e.target.value)} />
            </Field>
          ) : f.payout_method === "mobile_money" ? (
            <Field label={c.form.provider} htmlFor="payout_provider" error={err("payout_provider")}>
              <Select id="payout_provider" value={f.payout_provider} onChange={(e) => set("payout_provider", e.target.value)}>
                {PAYOUT_PROVIDERS.map((p) => (
                  <option key={p} value={p}>
                    {c.form.providers[p]}
                  </option>
                ))}
              </Select>
            </Field>
          ) : (
            <div />
          )}
          {f.payout_method && (
            <>
              <Field label={c.form.accountName} htmlFor="payout_account_name" error={err("payout_account_name")}>
                <Input id="payout_account_name" value={f.payout_account_name} onChange={(e) => set("payout_account_name", e.target.value)} />
              </Field>
              <Field
                label={f.payout_method === "bank" ? c.form.accountNumber : c.form.walletNumber}
                htmlFor="payout_account_number"
                error={err("payout_account_number")}
              >
                <Input id="payout_account_number" value={f.payout_account_number} onChange={(e) => set("payout_account_number", e.target.value)} />
              </Field>
            </>
          )}
        </div>
      </Card>
      </div>
      <div className="space-y-4">
        <Card title={t.logo}>
          <MediaInput label={t.studioLogo} value={logo} onChange={setLogo} aspect="aspect-square" />
        </Card>
        <Card title={t.partnership}>
          <dl className="space-y-3 text-sm">
            <div className="flex items-center justify-between">
              <dt className="text-text-muted">{t.revenueShare}</dt>
              <dd className="text-lg font-extrabold text-primary">{Number(company.revenue_share_percent ?? 0).toFixed(0)}%</dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-text-muted">{t.status}</dt>
              <dd>
                <StatusPill status={company.status} />
              </dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-text-muted">{t.slug}</dt>
              <dd className="font-mono text-xs">{company.slug}</dd>
            </div>
          </dl>
          <p className="mt-3 text-xs text-text-dim">{t.shareNote}</p>
        </Card>
        <Button type="submit" loading={saving} className="w-full">
          {t.save}
        </Button>
      </div>
    </form>
  );
}

/** `/studio/profile` returns `{company, user}`; accept a bare Company too. */
function unwrapCompany(d: unknown): Company | null {
  if (!d || typeof d !== "object") return null;
  const o = d as { company?: unknown };
  return (o.company && typeof o.company === "object" ? o.company : d) as Company;
}

export default function StudioProfilePage() {
  const { data: raw, loading, error, reload, mutate } = useApi<Company>("/studio/profile");
  const data = unwrapCompany(raw);
  const { setUser } = useAuth();
  const s = useT().studio;

  return (
    <>
      <PageHeader title={s.profile.title} description={s.profile.description} />
      {loading && !data ? (
        <div className="grid gap-4 lg:grid-cols-[1fr_300px]">
          <Skeleton className="h-[460px] rounded-2xl" />
          <Skeleton className="h-[460px] rounded-2xl" />
        </div>
      ) : error && !data ? (
        <ApiDownState action={<Button onClick={reload}>{s.retry}</Button>} />
      ) : data ? (
        <ProfileForm
          key={data.id}
          company={data}
          onSaved={(c) => {
            mutate(() => c);
            setUser((u) => (u ? { ...u, company: { ...(u.company ?? {}), ...c } } : u));
          }}
        />
      ) : null}
    </>
  );
}
