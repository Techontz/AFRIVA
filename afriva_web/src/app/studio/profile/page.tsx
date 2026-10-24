"use client";

import { useState, type FormEvent } from "react";
import { toast } from "sonner";
import { Card, PageHeader } from "@/components/portal/Kit";
import { appendMedia, MediaInput, type MediaValue } from "@/components/portal/MediaInput";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Skeleton, StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea } from "@/components/ui/Form";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useApi } from "@/lib/hooks";
import type { Company } from "@/lib/types";

const COUNTRIES = ["TZ", "KE", "UG", "RW", "NG", "GH", "ZA", "ET", "Other"];

function ProfileForm({ company, onSaved }: { company: Company; onSaved: (c: Company) => void }) {
  const [f, setF] = useState({
    name: company.name ?? "",
    email: company.email ?? "",
    phone: company.phone ?? "",
    country: company.country ?? "TZ",
    description: company.description ?? "",
  });
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
    if (logo.file) {
      const fd = new FormData();
      Object.entries(f).forEach(([k, v]) => fd.append(k, v));
      appendMedia(fd, "logo", logo);
      body = fd;
    } else {
      body = { ...f, logo_url: logo.url || null };
    }
    try {
      const saved = unwrapCompany(await api.put<Company>("/studio/profile", body));
      toast.success("Profile updated");
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
      <Card title="Studio details">
        <div className="grid gap-4">
          <Field label="Studio name" htmlFor="name" error={err("name")}>
            <Input id="name" required value={f.name} onChange={(e) => set("name", e.target.value)} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Contact email" htmlFor="email" error={err("email")}>
              <Input id="email" type="email" value={f.email} onChange={(e) => set("email", e.target.value)} />
            </Field>
            <Field label="Phone" htmlFor="phone" error={err("phone")}>
              <Input id="phone" type="tel" value={f.phone} onChange={(e) => set("phone", e.target.value)} placeholder="+255 7xx xxx xxx" />
            </Field>
          </div>
          <Field label="Country" htmlFor="country" error={err("country")}>
            <Select id="country" value={f.country} onChange={(e) => set("country", e.target.value)}>
              {[...new Set([f.country, ...COUNTRIES])].filter(Boolean).map((c) => (
                <option key={c}>{c}</option>
              ))}
            </Select>
          </Field>
          <Field label="About the studio" htmlFor="description" error={err("description")}>
            <Textarea id="description" rows={5} value={f.description} onChange={(e) => set("description", e.target.value)} />
          </Field>
        </div>
      </Card>
      <div className="space-y-4">
        <Card title="Logo">
          <MediaInput label="Studio logo" value={logo} onChange={setLogo} aspect="aspect-square" />
        </Card>
        <Card title="Partnership">
          <dl className="space-y-3 text-sm">
            <div className="flex items-center justify-between">
              <dt className="text-text-muted">Revenue share</dt>
              <dd className="text-lg font-extrabold text-primary">{Number(company.revenue_share_percent ?? 0).toFixed(0)}%</dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-text-muted">Status</dt>
              <dd>
                <StatusPill status={company.status} />
              </dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-text-muted">Slug</dt>
              <dd className="font-mono text-xs">{company.slug}</dd>
            </div>
          </dl>
          <p className="mt-3 text-xs text-text-dim">Revenue share is set by Afriva. Contact partners@afriva.com to change it.</p>
        </Card>
        <Button type="submit" loading={saving} className="w-full">
          Save profile
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

  return (
    <>
      <PageHeader title="Studio profile" description="How your studio appears to viewers and the Afriva team." />
      {loading && !data ? (
        <div className="grid gap-4 lg:grid-cols-[1fr_300px]">
          <Skeleton className="h-[460px] rounded-2xl" />
          <Skeleton className="h-[460px] rounded-2xl" />
        </div>
      ) : error && !data ? (
        <ApiDownState action={<Button onClick={reload}>Retry</Button>} />
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
