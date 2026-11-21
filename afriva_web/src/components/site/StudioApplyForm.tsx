"use client";

import Link from "next/link";
import { useRouter } from "@/lib/navigation";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { ApiError, api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { PAYOUT_PROVIDERS } from "@/lib/creator";
import { Button } from "../ui/Button";
import { Field, Input, Select } from "../ui/Form";
import { LogoMark } from "../ui/Logo";
import { CreatorGuidelinesModal } from "./CreatorGuidelines";

type Form = {
  full_name: string;
  phone: string;
  id_type: "nida" | "passport";
  id_number: string;
  payout_method: "mobile_money" | "bank";
  payout_provider: string;
  payout_bank_name: string;
  payout_account_name: string;
  payout_account_number: string;
  studio_name: string;
  email: string;
  password: string;
};

const EMPTY: Form = {
  full_name: "",
  phone: "",
  id_type: "nida",
  id_number: "",
  payout_method: "mobile_money",
  payout_provider: "mpesa",
  payout_bank_name: "",
  payout_account_name: "",
  payout_account_number: "",
  studio_name: "",
  email: "",
  password: "",
};

const MAX_ID_BYTES = 8 * 1024 * 1024;
const ID_TYPES = ["image/jpeg", "image/png", "application/pdf"];

function Choice<T extends string>({ value, options, onChange }: { value: T; options: { value: T; label: string }[]; onChange: (v: T) => void }) {
  return (
    <div className="grid grid-cols-2 gap-2">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          onClick={() => onChange(o.value)}
          className={`h-10 rounded-xl border px-3 text-sm font-semibold transition ${
            value === o.value ? "border-primary bg-primary/10 text-text" : "border-border text-text-muted hover:text-text"
          }`}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** "Request to post": short form for viewers (logged in) and guests. */
export function StudioApplyForm() {
  const t = useT().creator.form;
  const { user, loading } = useAuth();
  const router = useRouter();
  const guest = !user;
  const [form, setForm] = useState<Form>(EMPTY);
  const [file, setFile] = useState<File | null>(null);
  const [accepted, setAccepted] = useState(false);
  const [showGuide, setShowGuide] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  // Logged-in users who already sent a request go to its status page.
  useEffect(() => {
    if (!user) return;
    api
      .get<{ status: string } | null>("/me/studio-application")
      .then((a) => {
        if (a && a.status !== "rejected") router.replace("/apply/status");
      })
      .catch(() => {});
  }, [user, router]);

  const set = (key: keyof Form) => (e: { target: { value: string } }) => setForm({ ...form, [key]: e.target.value });

  const pickFile = (f: File | null) => {
    if (f && !ID_TYPES.includes(f.type)) return setErrors({ ...errors, id_document: t.fileType });
    if (f && f.size > MAX_ID_BYTES) return setErrors({ ...errors, id_document: t.fileTooBig });
    setErrors({ ...errors, id_document: "" });
    setFile(f);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const errs: Record<string, string> = {};
    const req = ["full_name", "phone", "payout_account_name", "payout_account_number"] as (keyof Form)[];
    if (form.payout_method === "bank") req.push("payout_bank_name");
    if (guest) req.push("email");
    for (const key of req) if (!String(form[key]).trim()) errs[key] = t.required;
    if (!form.id_number.trim() && !file) errs.id_number = t.idRequired;
    if (guest && form.email && !/^\S+@\S+\.\S+$/.test(form.email)) errs.email = t.invalidEmail;
    if (guest && form.password.length < 8) errs.password = t.passwordMin;
    if (!accepted) errs.guidelines_accepted = t.mustAccept;
    setErrors(errs);
    if (Object.keys(errs).length) return;

    const body = new FormData();
    const fields: (keyof Form)[] = ["full_name", "phone", "id_type", "id_number", "payout_method", "payout_account_name", "payout_account_number", "studio_name"];
    fields.push(form.payout_method === "bank" ? "payout_bank_name" : "payout_provider");
    if (guest) fields.push("email", "password");
    for (const k of fields) if (String(form[k]).trim()) body.set(k, String(form[k]).trim());
    if (file) body.set("id_document", file);
    body.set("guidelines_accepted", "1");

    setBusy(true);
    try {
      await api.post("/auth/studio-application", body);
      if (user) {
        router.push("/apply/status");
        return;
      }
      setSent(form.full_name.trim().split(" ")[0] ?? "");
    } catch (err) {
      if (err instanceof ApiError && err.errors) {
        setErrors(Object.fromEntries(Object.entries(err.errors).map(([k, v]) => [k, v[0] ?? ""])));
        toast.error(err.firstError);
      } else {
        toast.error(errorMessage(err));
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="relative grid min-h-[calc(100dvh-var(--header-h)-var(--tabbar-h))] place-items-center overflow-hidden px-4 py-10">
      <div className="relative w-full max-w-[520px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <LogoMark size={48} />
          <h1 className="mt-4 text-2xl font-extrabold tracking-tight">{sent !== null ? t.sentTitle : t.title}</h1>
          {sent === null && <p className="mt-1 text-sm text-text-muted">{t.subtitle}</p>}
        </div>

        {sent !== null ? (
          <div className="space-y-5 rounded-3xl border border-border bg-bg p-6 text-center shadow-xl sm:p-7">
            <p className="text-sm text-text-muted">{fmt(t.sentBody, { name: sent })}</p>
            <p className="text-sm text-text-muted">{t.sentGuest}</p>
            <Button href="/login?next=%2Fapply%2Fstatus" size="lg" className="w-full">
              {t.logIn}
            </Button>
          </div>
        ) : (
          <form onSubmit={submit} noValidate className="space-y-5 rounded-3xl border border-border bg-bg p-6 shadow-xl sm:p-7">
            <section className="space-y-4">
              <h2 className="text-sm font-bold uppercase tracking-wider text-text-dim">{t.yourDetails}</h2>
              <Field label={t.fullName} htmlFor="full_name" error={errors.full_name}>
                <Input id="full_name" autoComplete="name" value={form.full_name} onChange={set("full_name")} />
              </Field>
              <Field label={t.phone} htmlFor="phone" error={errors.phone}>
                <Input id="phone" type="tel" autoComplete="tel" placeholder="+255 7XX XXX XXX" value={form.phone} onChange={set("phone")} />
              </Field>
            </section>

            <section className="space-y-4">
              <h2 className="text-sm font-bold uppercase tracking-wider text-text-dim">{t.identity}</h2>
              <Field label={t.idType} error={errors.id_type}>
                <Choice
                  value={form.id_type}
                  onChange={(v) => setForm({ ...form, id_type: v })}
                  options={[
                    { value: "nida", label: t.nida },
                    { value: "passport", label: t.passport },
                  ]}
                />
              </Field>
              <Field label={t.idNumber} htmlFor="id_number" error={errors.id_number} hint={t.idHint}>
                <Input id="id_number" value={form.id_number} onChange={set("id_number")} autoComplete="off" />
              </Field>
              <Field label={t.idPhoto} error={errors.id_document}>
                <div className="flex items-center gap-3">
                  <input
                    ref={fileInput}
                    type="file"
                    accept="image/jpeg,image/png,application/pdf"
                    className="hidden"
                    onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
                  />
                  <Button type="button" variant="outline" size="sm" onClick={() => fileInput.current?.click()}>
                    {t.choosePhoto}
                  </Button>
                  {file && (
                    <>
                      <span className="min-w-0 truncate text-sm text-text-muted">{file.name}</span>
                      <button
                        type="button"
                        className="text-sm font-semibold text-primary hover:underline"
                        onClick={() => {
                          setFile(null);
                          if (fileInput.current) fileInput.current.value = "";
                        }}
                      >
                        {t.removePhoto}
                      </button>
                    </>
                  )}
                </div>
              </Field>
            </section>

            <section className="space-y-4">
              <h2 className="text-sm font-bold uppercase tracking-wider text-text-dim">{t.payout}</h2>
              <Choice
                value={form.payout_method}
                onChange={(v) => setForm({ ...form, payout_method: v })}
                options={[
                  { value: "mobile_money", label: t.mobileMoney },
                  { value: "bank", label: t.bank },
                ]}
              />
              {form.payout_method === "mobile_money" ? (
                <Field label={t.provider} htmlFor="payout_provider" error={errors.payout_provider}>
                  <Select id="payout_provider" value={form.payout_provider} onChange={set("payout_provider")}>
                    {PAYOUT_PROVIDERS.map((p) => (
                      <option key={p} value={p}>
                        {t.providers[p]}
                      </option>
                    ))}
                  </Select>
                </Field>
              ) : (
                <Field label={t.bankName} htmlFor="payout_bank_name" error={errors.payout_bank_name}>
                  <Input id="payout_bank_name" value={form.payout_bank_name} onChange={set("payout_bank_name")} />
                </Field>
              )}
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={t.accountName} htmlFor="payout_account_name" error={errors.payout_account_name}>
                  <Input id="payout_account_name" value={form.payout_account_name} onChange={set("payout_account_name")} />
                </Field>
                <Field
                  label={form.payout_method === "mobile_money" ? t.walletNumber : t.accountNumber}
                  htmlFor="payout_account_number"
                  error={errors.payout_account_number}
                >
                  <Input
                    id="payout_account_number"
                    inputMode={form.payout_method === "mobile_money" ? "tel" : "text"}
                    value={form.payout_account_number}
                    onChange={set("payout_account_number")}
                  />
                </Field>
              </div>
            </section>

            <Field label={t.studioName} htmlFor="studio_name" error={errors.studio_name} hint={t.studioNameHint}>
              <Input id="studio_name" autoComplete="organization" value={form.studio_name} onChange={set("studio_name")} />
            </Field>

            {guest && !loading && (
              <section className="space-y-4">
                <h2 className="text-sm font-bold uppercase tracking-wider text-text-dim">{t.login}</h2>
                <p className="-mt-2 text-xs text-text-dim">{t.loginHint}</p>
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label={t.email} htmlFor="email" error={errors.email}>
                    <Input id="email" type="email" autoComplete="email" value={form.email} onChange={set("email")} />
                  </Field>
                  <Field label={t.password} htmlFor="password" error={errors.password}>
                    <Input id="password" type="password" autoComplete="new-password" value={form.password} onChange={set("password")} />
                  </Field>
                </div>
              </section>
            )}

            <div>
              <div className="flex items-start gap-2 text-sm text-text-muted">
                <input
                  id="guidelines_accepted"
                  type="checkbox"
                  checked={accepted}
                  onChange={(e) => setAccepted(e.target.checked)}
                  className="mt-0.5 h-4 w-4 shrink-0 rounded border-border bg-surface accent-[#E90204]"
                />
                <span>
                  <label htmlFor="guidelines_accepted" className="cursor-pointer">
                    {t.accept}
                  </label>
                  <button type="button" onClick={() => setShowGuide(true)} className="font-semibold text-primary hover:underline">
                    {t.guidelinesLink}
                  </button>
                </span>
              </div>
              {errors.guidelines_accepted && <p className="mt-1 text-xs text-danger">{errors.guidelines_accepted}</p>}
            </div>

            <Button type="submit" loading={busy} disabled={!accepted} size="lg" className="w-full">
              {t.submit}
            </Button>
            {guest && (
              <p className="text-center text-sm text-text-muted">
                {t.haveAccount}
                <Link href="/login?next=%2Fapply%2Fstatus" className="font-semibold text-primary hover:underline">
                  {t.logIn}
                </Link>
              </p>
            )}
          </form>
        )}
      </div>
      <CreatorGuidelinesModal open={showGuide} onClose={() => setShowGuide(false)} />
    </div>
  );
}
