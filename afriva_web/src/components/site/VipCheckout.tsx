"use client";

import { useRef, useState } from "react";
import { useLocale, useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { isVip, useAuth } from "@/lib/auth";
import { cn, formatDate, formatMoney, formatNumber, planSummary } from "@/lib/format";
import type { CheckoutOptions, PaymentReturn } from "@/lib/payments";
import type { Plan } from "@/lib/types";
import { Icon } from "../ui/Icon";
import { PaymentPanel, TermsLine } from "./payments/PaymentPanel";

const PLAN_SECTIONS: { key: "vip" | "episodes" | "coins"; types: Plan["type"][] }[] = [
  { key: "vip", types: ["weekly", "monthly", "yearly"] },
  { key: "episodes", types: ["episodes"] },
  { key: "coins", types: ["coins"] },
];

export function VipCheckout({
  plans,
  options,
  next,
  paymentReturn,
}: {
  plans: Plan[];
  options: CheckoutOptions | null;
  next?: string;
  paymentReturn?: PaymentReturn | null;
}) {
  const { common: tc, user: tu } = useT();
  const t = tu.vip;
  const locale = useLocale();
  const { user } = useAuth();
  const defaultPlan = plans.find((p) => p.is_popular) ?? plans[0];
  const [planId, setPlanId] = useState<number | null>(defaultPlan?.id ?? null);
  const checkoutRef = useRef<HTMLDivElement>(null);

  const plan = plans.find((p) => p.id === planId) ?? null;
  // Come back to /vip (keeping the episode to resume, or the card payment to confirm) after logging in.
  const back = new URLSearchParams();
  if (next) back.set("next", next);
  if (paymentReturn) {
    back.set("payment", paymentReturn.reference);
    if (paymentReturn.cancelled) back.set("cancelled", "1");
  }
  const loginHref = `/login?next=${encodeURIComponent(back.size ? `/vip?${back}` : "/vip")}`;

  const pickPlan = (id: number) => {
    setPlanId(id);
    if (window.matchMedia("(max-width: 1023px)").matches) {
      checkoutRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  };

  const vip = isVip(user) ? user?.active_subscription : null;

  return (
    <div className="grid grid-cols-1 gap-8 lg:grid-cols-[minmax(0,1fr)_420px] lg:items-start">
      {/* Plans */}
      <div className="space-y-10">
        {vip && (
          <div className="flex items-center gap-3 rounded-2xl border border-primary/40 bg-primary/10 p-4 text-sm">
            <Icon name="crown" className="shrink-0 text-primary" />
            <p>
              {t.youreVip}
              {vip.plan?.name ? ` (${vip.plan.name})` : ""}
              {vip.ends_at ? fmt(t.until, { date: formatDate(vip.ends_at, false, locale) }) : ""}
              {t.extend}
            </p>
          </div>
        )}
        {PLAN_SECTIONS.map((section) => {
          const list = plans.filter((p) => section.types.includes(p.type));
          if (!list.length) return null;
          return (
            <section key={section.key} id={section.key} className="scroll-mt-24">
              <h2 className="mb-4 flex items-center gap-2 text-xl font-bold tracking-tight">
                {t.sections[section.key]}
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
                        "group relative flex flex-col rounded-[20px] border-2 p-5 text-left transition-all duration-200",
                        selected
                          ? "border-primary bg-primary/10"
                          : "border-transparent bg-surface hover:bg-surface-2",
                      )}
                    >
                      {p.is_popular && (
                        <span className="absolute -top-2.5 right-4 rounded-full bg-primary px-2.5 py-0.5 text-[10px] font-extrabold uppercase tracking-wider text-white">
                          {t.mostPopular}
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
                      <span className="mt-1 text-xs font-semibold text-text-muted">{planSummary(p, tc.plan)}</span>
                      {p.features && p.features.length > 0 && (
                        <ul className="mt-4 space-y-1.5">
                          {p.features.slice(0, 4).map((f) => (
                            <li key={f} className="flex items-start gap-2 text-xs text-text-muted">
                              <Icon name="check" size={14} className="mt-px shrink-0 text-text-dim" /> {f}
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
      <div ref={checkoutRef} className="scroll-mt-20 lg:sticky lg:top-[calc(var(--header-h)+1.5rem)]">
        <div className="rounded-[28px] bg-surface p-5 ring-1 ring-border/60 sm:p-6">
          <h2 className="text-lg font-extrabold">{t.checkout}</h2>
          {plan ? (
            <div className="mt-4 flex items-center gap-3 rounded-2xl bg-surface-2 p-4">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-brand text-white">
                <Icon name={plan.type === "coins" ? "coin" : plan.type === "episodes" ? "layers" : "crown"} size={19} />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate font-bold">{plan.name}</p>
                <p className="truncate text-xs text-text-muted">{planSummary(plan, tc.plan)}</p>
              </div>
              <p className="shrink-0 text-lg font-extrabold tabular-nums">{formatMoney(plan.price, plan.currency)}</p>
            </div>
          ) : (
            <p className="mt-4 text-sm text-text-muted">{t.choosePlan}</p>
          )}
          <PaymentPanel
            plan={plan}
            loginHref={loginHref}
            next={next}
            initialOptions={options}
            paymentReturn={paymentReturn}
            onRetryCard={() => checkoutRef.current?.scrollIntoView({ behavior: "smooth", block: "start" })}
          />
          <TermsLine />
        </div>
      </div>
    </div>
  );
}
