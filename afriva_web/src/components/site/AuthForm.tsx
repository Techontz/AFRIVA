"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useRouter } from "@/lib/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { type Portal, portalForHost, portalPathForRole, roleUrl } from "@/lib/portals";
import { cn, safeNextPath } from "@/lib/format";
import type { User } from "@/lib/types";
import { Button } from "../ui/Button";
import { Field, Input } from "../ui/Form";
import { Icon } from "../ui/Icon";
import { GOOGLE_CLIENT_ID, GoogleSignIn } from "./GoogleSignIn";
import { LogoMark } from "../ui/Logo";

const noSubscribe = () => () => {};

export function AuthForm({ mode }: { mode: "login" | "register" }) {
  const { user, loading, login, loginWithGoogle, register } = useAuth();
  const t = useT().user.auth;
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNextPath(params.get("next"));

  const [form, setForm] = useState({ name: "", login: "", password: "", confirm: "" });
  const [via, setVia] = useState<"email" | "phone">("email");
  const [showPw, setShowPw] = useState(false);
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [googleBusy, setGoogleBusy] = useState(false);
  const [googleError, setGoogleError] = useState("");
  // Studio/admin hosts have no viewer sign-up: studios apply instead, admins are created by Afriva.
  const portal = useSyncExternalStore<Portal | null>(noSubscribe, () => portalForHost(window.location.host), () => null);

  const destination = (u: User) => {
    // Creator applicants follow their request on the host they are on.
    if (next && (next === "/apply/status" || next.startsWith("/apply/status?"))) return next;
    if (u.role !== "viewer") {
      // Staff keep a deep link only when it points inside their own portal.
      const home = portalPathForRole(u.role);
      return roleUrl(u.role, next && (next === home || next.startsWith(`${home}/`) || next.startsWith(`${home}?`)) ? next : home);
    }
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
    if (mode === "register" && !form.name.trim()) errs.name = t.nameRequired;
    if (!form.login.trim()) errs.login = mode === "login" ? t.loginRequired : via === "email" ? t.emailRequired : t.phoneRequired;
    if (form.password.length < (mode === "register" ? 8 : 1)) errs.password = mode === "register" ? t.passwordMin : t.passwordRequired;
    if (mode === "register" && form.password !== form.confirm) errs.confirm = t.passwordMismatch;
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
      toast.success(fmt(mode === "login" ? t.welcomeBack : t.welcomeNew, { name: u.name.split(" ")[0] ?? "" }));
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

  const onGoogle = async (idToken: string) => {
    if (googleBusy || busy) return;
    setGoogleError("");
    setGoogleBusy(true);
    try {
      const u = await loginWithGoogle(idToken);
      toast.success(fmt(t.welcomeBack, { name: u.name.split(" ")[0] ?? "" }));
      router.replace(destination(u));
    } catch (err) {
      // 403 carries a localized account_rejected / account_suspended message from the API.
      const msg =
        err instanceof ApiError && err.status === 403 && err.message
          ? err.message
          : err instanceof ApiError && err.status === 0
            ? err.message
            : t.googleFailed;
      setGoogleError(msg);
    } finally {
      setGoogleBusy(false);
    }
  };

  const isLogin = mode === "login";
  const q = next ? `?next=${encodeURIComponent(next)}` : "";

  return (
    <div className="relative grid min-h-[calc(100dvh-var(--header-h)-var(--tabbar-h))] place-items-center overflow-hidden px-4 py-10">
      <div className="relative w-full max-w-[420px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <LogoMark size={48} />
          <h1 className="mt-5 text-[28px] font-extrabold tracking-tight">{isLogin ? t.loginTitle : t.registerTitle}</h1>
          <p className="mt-1 text-sm text-text-muted">
            {isLogin ? t.loginSubtitle : t.registerSubtitle}
          </p>
        </div>
        <form onSubmit={submit} noValidate className="space-y-4 rounded-[28px] bg-surface p-6 sm:p-7">
          {GOOGLE_CLIENT_ID && (
            <>
              <GoogleSignIn onCredential={onGoogle} busy={googleBusy} busyLabel={t.googleBusy} />
              {googleError && (
                <p role="alert" className="text-center text-sm font-medium text-danger">
                  {googleError}
                </p>
              )}
              <div className="flex items-center gap-3 text-xs font-semibold uppercase tracking-wider text-text-dim" aria-hidden="true">
                <span className="h-px flex-1 bg-border" />
                {t.or}
                <span className="h-px flex-1 bg-border" />
              </div>
            </>
          )}
          {!isLogin && (
            <Field label={t.fullName} htmlFor="name" error={errors.name}>
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
                  {v === "email" ? t.email : t.phone}
                </button>
              ))}
            </div>
          )}
          <Field
            label={isLogin ? t.emailOrPhone : via === "email" ? t.email : t.phoneNumber}
            htmlFor="login"
            error={errors.login}
          >
            <Input
              id="login"
              type={!isLogin && via === "email" ? "email" : !isLogin ? "tel" : "text"}
              autoComplete={isLogin ? "username" : via === "email" ? "email" : "tel"}
              placeholder={isLogin ? t.loginPlaceholder : via === "email" ? "you@example.com" : "+255 7XX XXX XXX"}
              value={form.login}
              onChange={(e) => setForm({ ...form, login: e.target.value })}
            />
          </Field>
          <Field label={t.password} htmlFor="password" error={errors.password}>
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
                aria-label={showPw ? t.hidePassword : t.showPassword}
              >
                <Icon name="eye" size={17} />
              </button>
            </div>
          </Field>
          {!isLogin && (
            <Field label={t.confirmPassword} htmlFor="confirm" error={errors.confirm}>
              <Input
                id="confirm"
                type={showPw ? "text" : "password"}
                autoComplete="new-password"
                value={form.confirm}
                onChange={(e) => setForm({ ...form, confirm: e.target.value })}
              />
            </Field>
          )}
          <Button type="submit" loading={busy} disabled={googleBusy} size="lg" className="w-full">
            {isLogin ? t.logIn : t.createAccount}
          </Button>
          {portal === "studio" ? (
            <p className="text-center text-sm text-text-muted">
              {t.studioCta}
              <Link href="/apply" className="font-semibold text-primary hover:underline">
                {t.studioApply}
              </Link>
            </p>
          ) : portal === "admin" ? (
            <p className="text-center text-sm text-text-muted">{t.adminHint}</p>
          ) : (
            <p className="text-center text-sm text-text-muted">
              {isLogin ? t.newHere : t.haveAccount}
              <Link href={`${isLogin ? "/register" : "/login"}${q}`} className="font-semibold text-primary hover:underline">
                {isLogin ? t.createAnAccount : t.logIn}
              </Link>
            </p>
          )}
        </form>
        <p className="mt-6 text-center text-xs text-text-dim">
          {t.staffHint}
        </p>
        {!portal && (
          <p className="mt-2 text-center text-xs text-text-dim">
            {t.studioCta}
            <Link href="/apply" className="font-semibold text-primary hover:underline">
              {t.studioApply}
            </Link>
          </p>
        )}
      </div>
    </div>
  );
}
