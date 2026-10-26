"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { ApiError, api, errorMessage, randomId, request } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatDate, formatMoney, formatNumber, planSummary } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { CheckoutResult, Payment, PaymentMethod, PaymentMethodType, Plan } from "@/lib/types";
import { Button } from "../ui/Button";
import { Spinner } from "../ui/Feedback";
import { Field, Input, Select } from "../ui/Form";
import { Icon, type IconName } from "../ui/Icon";

/** Scope §07: Tanzania pays by mobile money; outside Tanzania by card / wallet. */
const GROUPS: { type: PaymentMethodType; label: string; icon: IconName }[] = [
  { type: "mobile_money", label: "Tanzania: mobile money", icon: "phone" },
  { type: "card", label: "Worldwide: cards and wallets", icon: "card" },
  { type: "bank", label: "Bank", icon: "bank" },
];

const FLOW = ["Choose a package", "Pay with a secure provider", "Server confirms the payment", "Coins / VIP added", "Receipt saved"];

/** A method may only be used once it is connected and tested (`is_available`); older APIs omit the flag. */
const isAvailable = (m: PaymentMethod) => m.is_available ?? m.is_integrated ?? true;

const PLAN_SECTIONS: { key: string; title: string; types: Plan["type"][]; icon: IconName }[] = [
  { key: "vip", title: "VIP membership", types: ["weekly", "monthly", "yearly"], icon: "crown" },
  { key: "episodes", title: "Episode packs", types: ["episodes"], icon: "layers" },
  { key: "coins", title: "Coins", types: ["coins"], icon: "coin" },
];

type Phase =
  | { kind: "form" }
  | { kind: "pending"; reference: string; message: string; amount: number; currency: string; nextAction: string }
  | { kind: "success"; payment: Pick<Payment, "reference" | "amount" | "currency">; message: string }
  | { kind: "failed"; message: string };

function MethodLogo({ m }: { m: PaymentMethod }) {
  const color = m.color || "#262626";
  const label = m.name
    .replace(/\(.*\)/, "")
    .split(/\s+/)
    .map((w) => w[0])
    .join("")
    .slice(0, 3)
    .toUpperCase();
  return (
    <span
      className="grid h-9 w-12 shrink-0 place-items-center rounded-lg text-[11px] font-extrabold tracking-tight text-white"
      style={{ background: `linear-gradient(135deg, ${color}, ${color}cc)` }}
      aria-hidden="true"
    >
      {label}
    </span>
  );
}

export function VipCheckout({
  plans,
  methods,
  next,
}: {
  plans: Plan[];
  methods: PaymentMethod[];
  next?: string;
}) {
  const { user, loading: authLoading, refresh } = useAuth();
  const t = useT();
  const router = useRouter();
  const defaultPlan = plans.find((p) => p.is_popular) ?? plans[0];
  const [planId, setPlanId] = useState<number | null>(defaultPlan?.id ?? null);
  const enabled = methods.filter((m) => m.is_enabled !== false);
  const available = enabled.filter(isAvailable);
  const [methodCode, setMethodCode] = useState<string | null>(available[0]?.code ?? null);
  const [phone, setPhone] = useState("");
  const [card, setCard] = useState({ number: "", name: "", expiry: "", cvc: "" });
  const [bank, setBank] = useState({ account_name: "", account_number: "" });
  const [submitting, setSubmitting] = useState(false);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>({ kind: "form" });
  const checkoutRef = useRef<HTMLDivElement>(null);

  const plan = plans.find((p) => p.id === planId) ?? null;
  const method = available.find((m) => m.code === methodCode) ?? null;
  // One key per checkout attempt: a double click or network retry can't charge twice.
  const idempotencyKey = useRef<string | null>(null);
  const userPhone = user?.phone ?? "";

  // Poll payment status while pending.
  const pendingRef = phase.kind === "pending" ? phase.reference : null;
  useEffect(() => {
    if (!pendingRef) return;
    let tries = 0;
    let alive = true;
    const tick = async () => {
      tries++;
      try {
        const res = await api.get<Payment | { payment: Payment }>(`/payments/${pendingRef}`);
        const p = "payment" in res && res.payment ? res.payment : (res as Payment);
        if (!alive) return;
        if (p.status === "success") {
          setPhase({ kind: "success", payment: p, message: "Payment confirmed. Welcome to Afriva VIP!" });
          idempotencyKey.current = null;
          refresh();
          return;
        }
        if (p.status === "failed" || p.status === "cancelled") {
          setPhase({
            kind: "failed",
            message: p.status === "failed" ? "Payment failed. No money was taken." : "Payment cancelled. No money was taken.",
          });
          return;
        }
      } catch {
        /* keep polling */
      }
      if (alive && tries < 60) timer = setTimeout(tick, 4000);
    };
    let timer = setTimeout(tick, 3000);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [pendingRef, refresh]);

  const pickPlan = (id: number) => {
    setPlanId(id);
    idempotencyKey.current = null;
    if (window.matchMedia("(max-width: 1023px)").matches) {
      checkoutRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  };

  const submit = async () => {
    if (!user) {
      router.push(`/login?next=${encodeURIComponent("/vip")}`);
      return;
    }
    if (!plan || !method) return;
    const phoneValue = (phone || userPhone).trim();
    if (method.type === "mobile_money" && !/^\+?\d{9,15}$/.test(phoneValue.replace(/\s/g, ""))) {
      setPhoneError(t("Enter the mobile money number to charge, e.g. +255 7XX XXX XXX"));
      return;
    }
    setPhoneError(null);
    setSubmitting(true);
    try {
      const body: Record<string, unknown> = { plan_id: plan.id, payment_method: method.code };
      if (method.type === "mobile_money") body.phone = phoneValue.replace(/\s/g, "");
      if (method.type === "card") body.card = { name: card.name, last4: card.number.replace(/\D/g, "").slice(-4) };
      if (method.type === "bank") body.bank = { account_name: bank.account_name };
      idempotencyKey.current ??= randomId();
      const { data: res } = await request<{ data: CheckoutResult }>("/checkout", {
        method: "POST",
        body,
        headers: { "Idempotency-Key": idempotencyKey.current },
      });
      const pay = res.payment;
      if (pay.status !== "pending") idempotencyKey.current = null;
      if (res.next_action === "redirect" && res.redirect_url) {
        window.location.assign(res.redirect_url);
        return;
      }
      if (pay.status === "success") {
        setPhase({ kind: "success", payment: pay, message: res.message || "Payment successful." });
        refresh();
      } else if (pay.status === "failed" || pay.status === "cancelled") {
        setPhase({ kind: "failed", message: res.message || "Payment failed." });
      } else {
        setPhase({
          kind: "pending",
          reference: pay.reference,
          message: res.message || "Waiting for the payment provider to confirm.",
          amount: pay.amount,
          currency: pay.currency,
          nextAction: res.next_action,
        });
      }
    } catch (e) {
      if (e instanceof ApiError && e.errors?.phone) setPhoneError(e.errors.phone[0] ?? null);
      toast.error(errorMessage(e));
    } finally {
      setSubmitting(false);
    }
  };

  const vip = user?.active_subscription;

  return (
    <div className="grid gap-8 lg:grid-cols-[1fr_420px] lg:items-start">
      {/* Plans */}
      <div className="space-y-10">
        {vip && (
          <div className="flex items-center gap-3 rounded-2xl border border-primary/40 bg-primary/10 p-4 text-sm">
            <Icon name="crown" className="shrink-0 text-primary" />
            <p>
              {t("You're VIP")}
              {vip.plan?.name ? ` (${vip.plan.name})` : ""}
              {vip.ends_at ? ` ${t("until {date}", { date: formatDate(vip.ends_at) })}` : ""}. {t("Buying again extends your access.")}
            </p>
          </div>
        )}
        {PLAN_SECTIONS.map((section) => {
          const list = plans.filter((p) => section.types.includes(p.type));
          if (!list.length) return null;
          return (
            <section key={section.key} id={section.key} className="scroll-mt-24">
              <h2 className="mb-4 flex items-center gap-2 text-lg font-extrabold">
                <Icon name={section.icon} className={section.key === "episodes" ? "text-primary" : "text-primary"} />
                {t(section.title)}
              </h2>
              <div className="grid grid-cols-1 gap-3 min-[420px]:grid-cols-2 xl:grid-cols-3">
                {list.map((p) => {
                  const selected = p.id === planId;
                  return (
                    <button
                      key={p.id}
                      onClick={() => pickPlan(p.id)}
                      aria-pressed={selected}
                      className={cn(
                        "group relative flex flex-col rounded-2xl border p-5 text-left transition-all duration-200",
                        selected
                          ? "border-primary bg-primary/10"
                          : "border-border bg-surface hover:-translate-y-0.5 hover:border-text-dim/50",
                      )}
                    >
                      {p.is_popular && (
                        <span className="absolute -top-2.5 right-4 rounded-full bg-primary px-2.5 py-0.5 text-[10px] font-extrabold uppercase tracking-wider text-white">
                          {t("Most popular")}
                        </span>
                      )}
                      <span className="flex items-center justify-between">
                        <span className="font-bold">{p.name}</span>
                        <span
                          className={cn(
                            "grid h-5 w-5 place-items-center rounded-full border-2 transition",
                            selected ? "border-primary bg-primary" : "border-border",
                          )}
                        >
                          {selected && <Icon name="check" size={12} strokeWidth={3} />}
                        </span>
                      </span>
                      <span className="mt-3 text-[26px] font-extrabold tracking-tight">
                        {formatNumber(p.price)}
                        <span className="ml-1 text-sm font-semibold text-text-muted">{p.currency}</span>
                      </span>
                      <span className="mt-1 text-xs font-semibold text-text-muted">{planSummary(p, t)}</span>
                      {p.features && p.features.length > 0 && (
                        <ul className="mt-4 space-y-1.5 border-t border-border/70 pt-4">
                          {p.features.slice(0, 4).map((f) => (
                            <li key={f} className="flex items-start gap-2 text-xs text-text-muted">
                              <Icon name="check" size={14} className="mt-px shrink-0 text-success" /> {f}
                            </li>
                          ))}
                        </ul>
                      )}
                    </button>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>

      {/* Checkout */}
      <div ref={checkoutRef} className="scroll-mt-20 lg:sticky lg:top-24">
        <div className="rounded-3xl border border-border bg-surface p-5 sm:p-6">
          {phase.kind === "form" ? (
            <>
              <h2 className="text-lg font-extrabold">{t("Checkout")}</h2>
              {plan ? (
                <div className="mt-4 flex items-center justify-between rounded-2xl bg-surface-2 p-4">
                  <div className="min-w-0">
                    <p className="truncate font-bold">{plan.name}</p>
                    <p className="text-xs text-text-muted">{planSummary(plan, t)}</p>
                  </div>
                  <p className="shrink-0 text-lg font-extrabold">{formatMoney(plan.price, plan.currency)}</p>
                </div>
              ) : (
                <p className="mt-4 text-sm text-text-muted">{t("Choose a plan to continue.")}</p>
              )}

              <div className="mt-6 space-y-5">
                {GROUPS.map((g) => {
                  const list = available.filter((m) => m.type === g.type);
                  const soon = enabled.filter((m) => m.type === g.type && !isAvailable(m));
                  if (!list.length && !soon.length) return null;
                  return (
                    <fieldset key={g.type}>
                      <legend className="mb-2 flex items-center gap-1.5 text-xs font-bold uppercase tracking-[0.12em] text-text-dim">
                        <Icon name={g.icon} size={14} /> {t(g.label)}
                      </legend>
                      <div className={cn("grid gap-2", g.type === "mobile_money" ? "grid-cols-1 min-[400px]:grid-cols-2" : "grid-cols-1 min-[400px]:grid-cols-2")}>
                        {list.map((m) => {
                          const active = m.code === methodCode;
                          return (
                            <label
                              key={m.code}
                              className={cn(
                                "flex cursor-pointer items-center gap-2.5 rounded-xl border p-2.5 transition-colors duration-150",
                                active ? "border-primary bg-primary/10" : "border-border hover:border-text-dim/50 hover:bg-surface-2",
                              )}
                            >
                              <input
                                type="radio"
                                name="payment_method"
                                value={m.code}
                                checked={active}
                                onChange={() => {
                                  setMethodCode(m.code);
                                  idempotencyKey.current = null;
                                }}
                                className="sr-only"
                              />
                              <MethodLogo m={m} />
                              <span className="min-w-0 flex-1 truncate text-[13px] font-semibold">{m.name}</span>
                              {active && <Icon name="check" size={16} className="text-primary" strokeWidth={2.6} />}
                            </label>
                          );
                        })}
                        {soon.map((m) => (
                          <div
                            key={m.code}
                            aria-disabled="true"
                            className="flex cursor-not-allowed items-center gap-2.5 rounded-xl border border-dashed border-border p-2.5 opacity-55"
                          >
                            <MethodLogo m={m} />
                            <span className="min-w-0 flex-1">
                              <span className="block truncate text-[13px] font-semibold">{m.name}</span>
                              <span className="block text-[11px] text-text-dim">{t("Coming soon")}</span>
                            </span>
                          </div>
                        ))}
                      </div>
                    </fieldset>
                  );
                })}
                {!available.length && <p className="text-sm text-text-muted">{t("No payment methods are available right now.")}</p>}
              </div>

              <ol className="mt-5 space-y-1.5 rounded-2xl bg-surface-2/60 p-4 text-xs text-text-muted">
                {FLOW.map((step, i) => (
                  <li key={step} className="flex items-center gap-2">
                    <span className="grid h-5 w-5 shrink-0 place-items-center rounded-full bg-surface text-[10px] font-bold text-text">{i + 1}</span>
                    {t(step)}
                  </li>
                ))}
              </ol>

              {/* Method-specific details */}
              {method && (
                <div className="mt-5 space-y-3 rounded-2xl border border-border/70 bg-bg/40 p-4 animate-fade-in">
                  {method.type === "mobile_money" && (
                    <Field
                      label={t("{method} number", { method: method.name })}
                      htmlFor="mm-phone"
                      error={phoneError}
                      hint={t("You'll get a prompt on your phone to enter your PIN.")}
                    >
                      <Input
                        id="mm-phone"
                        type="tel"
                        inputMode="tel"
                        autoComplete="tel"
                        placeholder="+255 7XX XXX XXX"
                        value={phone || userPhone}
                        onChange={(e) => setPhone(e.target.value)}
                      />
                    </Field>
                  )}
                  {method.type === "card" && (
                    <>
                      <Field label={t("Card number")} htmlFor="cc-number">
                        <Input
                          id="cc-number"
                          inputMode="numeric"
                          autoComplete="cc-number"
                          placeholder="4242 4242 4242 4242"
                          value={card.number}
                          onChange={(e) =>
                            setCard({
                              ...card,
                              number: e.target.value.replace(/\D/g, "").slice(0, 16).replace(/(.{4})/g, "$1 ").trim(),
                            })
                          }
                        />
                      </Field>
                      <Field label={t("Name on card")} htmlFor="cc-name">
                        <Input id="cc-name" autoComplete="cc-name" value={card.name} onChange={(e) => setCard({ ...card, name: e.target.value })} />
                      </Field>
                      <div className="grid grid-cols-2 gap-3">
                        <Field label={t("Expiry")} htmlFor="cc-exp">
                          <Input
                            id="cc-exp"
                            autoComplete="cc-exp"
                            placeholder={t("MM/YY")}
                            value={card.expiry}
                            onChange={(e) => {
                              const d = e.target.value.replace(/\D/g, "").slice(0, 4);
                              setCard({ ...card, expiry: d.length > 2 ? `${d.slice(0, 2)}/${d.slice(2)}` : d });
                            }}
                          />
                        </Field>
                        <Field label="CVC" htmlFor="cc-cvc">
                          <Input
                            id="cc-cvc"
                            inputMode="numeric"
                            autoComplete="cc-csc"
                            placeholder="123"
                            value={card.cvc}
                            onChange={(e) => setCard({ ...card, cvc: e.target.value.replace(/\D/g, "").slice(0, 4) })}
                          />
                        </Field>
                      </div>
                      <p className="flex items-center gap-1.5 text-xs text-text-dim">
                        <Icon name="shield" size={14} /> {t("Card details go straight to the card processor, never stored by Afriva.")}
                      </p>
                    </>
                  )}
                  {method.type === "bank" && (
                    <>
                      <Field label={t("Account holder name")} htmlFor="bank-name">
                        <Input id="bank-name" value={bank.account_name} onChange={(e) => setBank({ ...bank, account_name: e.target.value })} />
                      </Field>
                      <Field
                        label={t("Pay from")}
                        htmlFor="bank-channel"
                        hint={t("You'll receive {method} payment instructions and a control number.", { method: method.name })}
                      >
                        <Select id="bank-channel" defaultValue="internet">
                          <option value="internet">{t("Internet / mobile banking")}</option>
                          <option value="branch">{t("Branch deposit")}</option>
                          <option value="agent">{t("Bank agent")}</option>
                        </Select>
                      </Field>
                    </>
                  )}
                </div>
              )}

              {authLoading ? (
                <div className="skeleton mt-6 h-12 rounded-full" />
              ) : user ? (
                <Button onClick={submit} loading={submitting} disabled={!plan || !method} size="lg" className="mt-6 w-full">
                  {plan ? t("Pay {amount}", { amount: formatMoney(plan.price, plan.currency) }) : t("Pay")}
                </Button>
              ) : (
                <Button href={`/login?next=${encodeURIComponent("/vip")}`} size="lg" className="mt-6 w-full">
                  {t("Log in to subscribe")}
                </Button>
              )}
              <p className="mt-3 text-center text-[11px] leading-relaxed text-text-dim">
                {t("By paying you agree to our")}{" "}
                <Link href="/info/terms" className="underline hover:text-text">
                  {t("Terms")}
                </Link>
                {t(". VIP plans don't auto-renew.")} {t("Afriva only confirms a payment after the provider confirms it to our server.")}
              </p>
            </>
          ) : phase.kind === "pending" ? (
            <div className="py-4 text-center animate-fade-in">
              <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-primary/15 text-primary">
                <Spinner size={30} />
              </div>
              <h2 className="mt-4 text-lg font-extrabold">{t("Payment pending")}</h2>
              <p className="mt-1 text-sm text-text-muted">{t(phase.message)}</p>
              {phase.nextAction === "await_ussd" && (
                <p className="mt-3 rounded-xl bg-surface-2 p-3 text-sm text-text-muted">
                  {t("Check your phone and enter your mobile money PIN to approve")}{" "}
                  <span className="font-bold text-text">{formatMoney(phase.amount, phase.currency)}</span>.
                </p>
              )}
              <p className="mt-4 text-xs text-text-dim">
                {t("Reference")} <span className="font-mono text-text-muted">{phase.reference}</span>{" "}
                {t("· we'll update this page automatically.")}
              </p>
              <Button variant="secondary" className="mt-6" onClick={() => setPhase({ kind: "form" })}>
                {t("Choose another method")}
              </Button>
            </div>
          ) : phase.kind === "success" ? (
            <div className="py-4 text-center animate-pop-in">
              <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-success/15 text-success">
                <Icon name="check" size={32} strokeWidth={2.6} />
              </div>
              <h2 className="mt-4 text-lg font-extrabold">{t("You're all set!")}</h2>
              <p className="mt-1 text-sm text-text-muted">{t(phase.message)}</p>
              <p className="mt-3 text-xs text-text-dim">
                {formatMoney(phase.payment.amount, phase.payment.currency)} · {t("Ref")}{" "}
                <span className="font-mono">{phase.payment.reference}</span>
              </p>
              <div className="mt-6 flex flex-col gap-2">
                <Button href={next || "/"} size="lg">
                  <Icon name="play" size={15} /> {next ? t("Continue watching") : t("Start watching")}
                </Button>
                <Button href={`/account?tab=payments&receipt=${encodeURIComponent(phase.payment.reference)}`} variant="ghost">
                  <Icon name="list" size={15} /> {t("View receipt")}
                </Button>
              </div>
            </div>
          ) : (
            <div className="py-4 text-center">
              <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-danger/15 text-danger">
                <Icon name="x" size={30} />
              </div>
              <h2 className="mt-4 text-lg font-extrabold">{t("Payment didn't go through")}</h2>
              <p className="mt-1 text-sm text-text-muted">{t(phase.message)}</p>
              <Button className="mt-6" onClick={() => setPhase({ kind: "form" })}>
                {t("Try again")}
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
