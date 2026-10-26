"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { ApiError, errorMessage } from "@/lib/api";
import { homeForRole, useAuth } from "@/lib/auth";
import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { User } from "@/lib/types";
import { Button } from "../ui/Button";
import { Field, Input } from "../ui/Form";
import { Icon } from "../ui/Icon";
import { LogoMark } from "../ui/Logo";

function safeNext(v: string | null) {
  return v && v.startsWith("/") && !v.startsWith("//") ? v : null;
}

export function AuthForm({ mode }: { mode: "login" | "register" }) {
  const { user, loading, login, register } = useAuth();
  const t = useT();
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));

  const [form, setForm] = useState({ name: "", login: "", password: "", confirm: "" });
  const [via, setVia] = useState<"email" | "phone">("email");
  const [showPw, setShowPw] = useState(false);
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const destination = (u: User) => {
    if (u.role !== "viewer") return homeForRole(u.role);
    return next ?? "/";
  };

  // Already signed in → bounce to the right home.
  useEffect(() => {
    if (!loading && user) router.replace(destination(user));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, user]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const errs: Record<string, string> = {};
    if (mode === "register" && !form.name.trim()) errs.name = t("Tell us your name");
    if (!form.login.trim()) errs.login = mode === "login" ? t("Enter your email or phone") : via === "email" ? t("Enter your email") : t("Enter your phone");
    if (form.password.length < (mode === "register" ? 8 : 1)) errs.password = mode === "register" ? t("Use at least 8 characters") : t("Enter your password");
    if (mode === "register" && form.password !== form.confirm) errs.confirm = t("Passwords don't match");
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setBusy(true);
    try {
      const u =
        mode === "login"
          ? await login(form.login.trim(), form.password)
          : await register({
              name: form.name.trim(),
              password: form.password,
              ...(via === "email" ? { email: form.login.trim() } : { phone: form.login.replace(/\s/g, "") }),
            });
      toast.success(mode === "login" ? t("Welcome back, {name}!", { name: u.name.split(" ")[0] }) : t("Welcome to Afriva, {name}!", { name: u.name.split(" ")[0] }));
      router.replace(destination(u));
    } catch (err) {
      if (err instanceof ApiError && err.errors) {
        const mapped: Record<string, string> = {};
        for (const [k, v] of Object.entries(err.errors)) {
          const key = k === "email" || k === "phone" ? "login" : k;
          mapped[key] = v[0] ?? "";
        }
        setErrors(mapped);
      }
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const isLogin = mode === "login";
  const q = next ? `?next=${encodeURIComponent(next)}` : "";

  return (
    <div className="relative grid min-h-[calc(100dvh-4rem)] lg:min-h-[calc(100dvh-88px)] place-items-center overflow-hidden px-4 py-10">
      <div className="relative w-full max-w-[420px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <LogoMark size={48} />
          <h1 className="mt-4 text-2xl font-extrabold tracking-tight">{isLogin ? t("Welcome back") : t("Create your account")}</h1>
          <p className="mt-1 text-sm text-text-muted">
            {isLogin ? t("Log in to continue your dramas.") : t("Save your progress, build My List and go VIP.")}
          </p>
        </div>
        <form onSubmit={submit} noValidate className="space-y-4 rounded-3xl border border-border bg-bg p-6 shadow-xl sm:p-7">
          {!isLogin && (
            <Field label={t("Full name")} htmlFor="name" error={errors.name}>
              <Input id="name" autoComplete="name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </Field>
          )}
          {!isLogin && (
            <div className="flex rounded-full bg-surface-2 p-1 text-xs font-bold">
              {(["email", "phone"] as const).map((v) => (
                <button
                  type="button"
                  key={v}
                  onClick={() => setVia(v)}
                  className={cn("flex-1 rounded-full py-1.5 capitalize transition", via === v ? "bg-surface text-text shadow" : "text-text-dim")}
                >
                  {v === "email" ? t("Email") : t("Phone")}
                </button>
              ))}
            </div>
          )}
          <Field
            label={isLogin ? t("Email or phone") : via === "email" ? t("Email") : t("Phone number")}
            htmlFor="login"
            error={errors.login}
          >
            <Input
              id="login"
              type={!isLogin && via === "email" ? "email" : !isLogin ? "tel" : "text"}
              autoComplete={isLogin ? "username" : via === "email" ? "email" : "tel"}
              placeholder={isLogin ? t("you@example.com or +2557…") : via === "email" ? "you@example.com" : "+255 7XX XXX XXX"}
              value={form.login}
              onChange={(e) => setForm({ ...form, login: e.target.value })}
            />
          </Field>
          <Field label={t("Password")} htmlFor="password" error={errors.password}>
            <div className="relative">
              <Input
                id="password"
                type={showPw ? "text" : "password"}
                autoComplete={isLogin ? "current-password" : "new-password"}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                className="pr-11"
              />
              <button
                type="button"
                onClick={() => setShowPw((s) => !s)}
                className="absolute right-2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-full text-text-dim hover:text-text"
                aria-label={showPw ? t("Hide password") : t("Show password")}
              >
                <Icon name="eye" size={17} />
              </button>
            </div>
          </Field>
          {!isLogin && (
            <Field label={t("Confirm password")} htmlFor="confirm" error={errors.confirm}>
              <Input
                id="confirm"
                type={showPw ? "text" : "password"}
                autoComplete="new-password"
                value={form.confirm}
                onChange={(e) => setForm({ ...form, confirm: e.target.value })}
              />
            </Field>
          )}
          <Button type="submit" loading={busy} size="lg" className="w-full">
            {isLogin ? t("Log in") : t("Create account")}
          </Button>
          <p className="text-center text-sm text-text-muted">
            {isLogin ? t("New to Afriva?") : t("Already have an account?")}{" "}
            <Link href={`${isLogin ? "/register" : "/login"}${q}`} className="font-semibold text-primary hover:underline">
              {isLogin ? t("Create an account") : t("Log in")}
            </Link>
          </p>
        </form>
        <p className="mt-6 text-center text-xs text-text-dim">
          {t("Studio partner or admin? Log in here and you'll be taken to your portal.")}
        </p>
      </div>
    </div>
  );
}
