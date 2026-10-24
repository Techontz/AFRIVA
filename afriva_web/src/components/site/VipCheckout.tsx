"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { ApiError, api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatDate, formatMoney, formatNumber, planSummary } from "@/lib/format";
import type { CheckoutResult, Payment, PaymentMethod, PaymentMethodType, Plan } from "@/lib/types";
import { Button } from "../ui/Button";
import { Spinner } from "../ui/Feedback";
import { Field, Input, Select } from "../ui/Form";
import { Icon, type IconName } from "../ui/Icon";

const GROUPS: { type: PaymentMethodType; label: string; icon: IconName }[] = [
  { type: "mobile_money", label: "Mobile Money", icon: "phone" },
  { type: "card", label: "Cards", icon: "card" },
  { type: "bank", label: "Bank", icon: "bank" },
];

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
  const router = useRouter();
  const defaultPlan = plans.find((p) => p.is_popular) ?? plans[0];
  const [planId, setPlanId] = useState<number | null>(defaultPlan?.id ?? null);
  const enabled = methods.filter((m) => m.is_enabled !== false);
  const [methodCode, setMethodCode] = useState<string | null>(enabled[0]?.code ?? null);
  const [phone, setPhone] = useState("");
  const [card, setCard] = useState({ number: "", name: "", expiry: "", cvc: "" });
  const [bank, setBank] = useState({ account_name: "", account_number: "" });
  const [submitting, setSubmitting] = useState(false);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>({ kind: "form" });
  const checkoutRef = useRef<HTMLDivElement>(null);

  const plan = plans.find((p) => p.id === planId) ?? null;
  const method = enabled.find((m) => m.code === methodCode) ?? null;
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
          refresh();
          return;
        }
        if (p.status === "failed" || p.status === "cancelled") {
          setPhase({ kind: "failed", message: `Payment ${p.status}. No money was taken.` });
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
      setPhoneError("Enter the mobile money number to charge, e.g. +255 7XX XXX XXX");
      return;
    }
    setPhoneError(null);
    setSubmitting(true);
    try {
      const body: Record<string, unknown> = { plan_id: plan.id, payment_method: method.code };
      if (method.type === "mobile_money") body.phone = phoneValue.replace(/\s/g, "");
      if (method.type === "card") body.card = { name: card.name, last4: card.number.replace(/\D/g, "").slice(-4) };
      if (method.type === "bank") body.bank = { account_name: bank.account_name };
      const res = await api.post<CheckoutResult>("/checkout", body);
      const pay = res.payment;
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
          message: res.message || "Pending — payment provider not yet connected",
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
              You&apos;re VIP{vip.plan?.name ? ` (${vip.plan.name})` : ""}
              {vip.ends_at ? ` until ${formatDate(vip.ends_at)}` : ""}. Buying again extends your access.
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
                {section.title}
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
                          Most popular
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
                      <span className="mt-1 text-xs font-semibold text-text-muted">{planSummary(p)}</span>
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
              <h2 className="text-lg font-extrabold">Checkout</h2>
              {plan ? (
                <div className="mt-4 flex items-center justify-between rounded-2xl bg-surface-2 p-4">
                  <div className="min-w-0">
                    <p className="truncate font-bold">{plan.name}</p>
                    <p className="text-xs text-text-muted">{planSummary(plan)}</p>
                  </div>
                  <p className="shrink-0 text-lg font-extrabold">{formatMoney(plan.price, plan.currency)}</p>
                </div>
              ) : (
                <p className="mt-4 text-sm text-text-muted">Choose a plan to continue.</p>
              )}

              <div className="mt-6 space-y-5">
                {GROUPS.map((g) => {
                  const list = enabled.filter((m) => m.type === g.type);
                  if (!list.length) return null;
                  return (
                    <fieldset key={g.type}>
                      <legend className="mb-2 flex items-center gap-1.5 text-xs font-bold uppercase tracking-[0.12em] text-text-dim">
                        <Icon name={g.icon} size={14} /> {g.label}
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
                                onChange={() => setMethodCode(m.code)}
                                className="sr-only"
                              />
                              <MethodLogo m={m} />
                              <span className="min-w-0 flex-1 truncate text-[13px] font-semibold">{m.name}</span>
                              {active && <Icon name="check" size={16} className="text-primary" strokeWidth={2.6} />}
                            </label>
                          );
                        })}
                      </div>
                    </fieldset>
                  );
                })}
                {!enabled.length && <p className="text-sm text-text-muted">No payment methods are available right now.</p>}
              </div>

              {/* Method-specific details */}
              {method && (
                <div className="mt-5 space-y-3 rounded-2xl border border-border/70 bg-bg/40 p-4 animate-fade-in">
                  {method.type === "mobile_money" && (
                    <Field
                      label={`${method.name} number`}
                      htmlFor="mm-phone"
                      error={phoneError}
                      hint="You'll get a prompt on your phone to enter your PIN."
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
                      <Field label="Card number" htmlFor="cc-number">
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
                      <Field label="Name on card" htmlFor="cc-name">
                        <Input id="cc-name" autoComplete="cc-name" value={card.name} onChange={(e) => setCard({ ...card, name: e.target.value })} />
                      </Field>
                      <div className="grid grid-cols-2 gap-3">
                        <Field label="Expiry" htmlFor="cc-exp">
                          <Input
                            id="cc-exp"
                            autoComplete="cc-exp"
                            placeholder="MM/YY"
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
                        <Icon name="shield" size={14} /> Card details go straight to the card processor, never stored by Afriva.
                      </p>
                    </>
                  )}
                  {method.type === "bank" && (
                    <>
                      <Field label="Account holder name" htmlFor="bank-name">
                        <Input id="bank-name" value={bank.account_name} onChange={(e) => setBank({ ...bank, account_name: e.target.value })} />
                      </Field>
                      <Field label="Pay from" htmlFor="bank-channel" hint={`You'll receive ${method.name} payment instructions and a control number.`}>
                        <Select id="bank-channel" defaultValue="internet">
                          <option value="internet">Internet / mobile banking</option>
                          <option value="branch">Branch deposit</option>
                          <option value="agent">Bank agent</option>
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
                  {plan ? `Pay ${formatMoney(plan.price, plan.currency)}` : "Pay"}
                </Button>
              ) : (
                <Button href={`/login?next=${encodeURIComponent("/vip")}`} size="lg" className="mt-6 w-full">
                  Log in to subscribe
                </Button>
              )}
              <p className="mt-3 text-center text-[11px] leading-relaxed text-text-dim">
                By paying you agree to our{" "}
                <Link href="/info/terms" className="underline hover:text-text">
                  Terms
                </Link>
                . VIP plans don&apos;t auto-renew.
              </p>
            </>
          ) : phase.kind === "pending" ? (
            <div className="py-4 text-center animate-fade-in">
              <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-primary/15 text-primary">
                <Spinner size={30} />
              </div>
              <h2 className="mt-4 text-lg font-extrabold">Payment pending</h2>
              <p className="mt-1 text-sm text-text-muted">{phase.message}</p>
              {phase.nextAction === "await_ussd" && (
                <p className="mt-3 rounded-xl bg-surface-2 p-3 text-sm text-text-muted">
                  Check your phone and enter your mobile money PIN to approve{" "}
                  <span className="font-bold text-text">{formatMoney(phase.amount, phase.currency)}</span>.
                </p>
              )}
              <p className="mt-4 text-xs text-text-dim">
                Reference <span className="font-mono text-text-muted">{phase.reference}</span> · we&apos;ll update this page automatically.
              </p>
              <Button variant="secondary" className="mt-6" onClick={() => setPhase({ kind: "form" })}>
                Choose another method
              </Button>
            </div>
          ) : phase.kind === "success" ? (
            <div className="py-4 text-center animate-pop-in">
              <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-success/15 text-success">
                <Icon name="check" size={32} strokeWidth={2.6} />
              </div>
              <h2 className="mt-4 text-lg font-extrabold">You&apos;re all set!</h2>
              <p className="mt-1 text-sm text-text-muted">{phase.message}</p>
              <p className="mt-3 text-xs text-text-dim">
                {formatMoney(phase.payment.amount, phase.payment.currency)} · Ref{" "}
                <span className="font-mono">{phase.payment.reference}</span>
              </p>
              <div className="mt-6 flex flex-col gap-2">
                <Button href={next || "/"} size="lg">
                  <Icon name="play" size={15} /> {next ? "Continue watching" : "Start watching"}
                </Button>
                <Button href="/account?tab=payments" variant="ghost">
                  View receipt
                </Button>
              </div>
            </div>
          ) : (
            <div className="py-4 text-center">
              <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-danger/15 text-danger">
                <Icon name="x" size={30} />
              </div>
              <h2 className="mt-4 text-lg font-extrabold">Payment didn&apos;t go through</h2>
              <p className="mt-1 text-sm text-text-muted">{phase.message}</p>
              <Button className="mt-6" onClick={() => setPhase({ kind: "form" })}>
                Try again
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
