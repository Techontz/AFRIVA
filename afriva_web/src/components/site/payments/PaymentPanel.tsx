"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { ApiError, api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatMoney } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import {
  cardDigits,
  cardLengthOk,
  detectBrand,
  detectNetwork,
  expiryInPast,
  luhnValid,
  normalizePhone,
  parseExpiry,
  savedLabel,
  spaceLocal,
  localDigits,
  networkName,
  type Channel,
  type CheckoutOptions,
  type CheckoutResponse,
  type SavedMethod,
} from "@/lib/payments";
import type { Payment, Plan } from "@/lib/types";
import { Button } from "../../ui/Button";
import { Toggle } from "../../ui/Form";
import { Icon } from "../../ui/Icon";
import { CardFields, PhoneField, type CardDraft, type CardErrors } from "./PayFields";
import { SavedMethodIcon } from "./PayMarks";
import { PaymentStatusModal, type PayStatus } from "./PaymentStatusModal";

const POLL_MS = 3000;
const POLL_WINDOW_MS = 120_000;
const EMPTY_CARD: CardDraft = { number: "", expiry: "", cvc: "" };

type Selection = { kind: "saved"; id: number } | { kind: "new" };
type Body = Record<string, unknown>;
/** What the status modal needs to describe the attempt (never card numbers). */
type Attempt = { channel: Channel; phone?: string | null; methodCode?: string | null; methodName?: string | null };

/**
 * The payment step of checkout: saved methods first (one tap), otherwise mobile money or card.
 * Mobile money never asks for a network: it is detected from the number, and the PIN is entered
 * only on the USSD prompt the network pushes to the phone. There is no PIN field in Afriva.
 */
export function PaymentPanel({
  plan,
  loginHref,
  next,
  initialOptions,
}: {
  plan: Plan | null;
  loginHref: string;
  next?: string;
  initialOptions: CheckoutOptions | null;
}) {
  const t = useT().user.pay;
  const { user, loading: authLoading, refresh } = useAuth();

  const optionsReq = useApi<CheckoutOptions>(initialOptions ? null : "/checkout/options");
  const options = initialOptions ?? optionsReq.data;
  const savedReq = useApi<SavedMethod[]>(user ? "/me/payment-methods" : null);
  const reloadSaved = savedReq.reload;
  const saved = useMemo(() => (user ? (savedReq.data ?? []) : []), [user, savedReq.data]);

  const mmOk = options?.mobile_money.available ?? true;
  const cardOk = options?.card.available ?? true;
  const usable = useCallback(
    (m: SavedMethod) => !m.is_expired && m.one_tap && (m.type === "card" ? cardOk : mmOk),
    [cardOk, mmOk],
  );

  const [selection, setSelection] = useState<Selection | null>(null);
  const [channel, setChannel] = useState<Channel | null>(null);
  const [phone, setPhone] = useState<string | null>(null);
  const [card, setCard] = useState<CardDraft>(EMPTY_CARD);
  const [save, setSave] = useState(true);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [cardErrors, setCardErrors] = useState<CardErrors>({});
  const [submitting, setSubmitting] = useState(false);
  const [status, setStatus] = useState<PayStatus | null>(null);
  const lastBody = useRef<{ body: Body; attempt: Attempt } | null>(null);

  // Defaults: the default (or most recent) one-tap method, else a new entry on the first open channel.
  const preferred = saved.find((m) => m.is_default && usable(m)) ?? saved.find(usable) ?? null;
  const sel: Selection = selection ?? (preferred ? { kind: "saved", id: preferred.id } : { kind: "new" });
  const activeChannel: Channel = channel ?? (mmOk || !cardOk ? "mobile_money" : "card");
  const selectedSaved = sel.kind === "saved" ? (saved.find((m) => m.id === sel.id) ?? null) : null;
  const phoneValue = phone ?? (user?.phone && normalizePhone(user.phone) ? spaceLocal(localDigits(user.phone)) : "");

  /* -------------------------------------------------------------- polling */
  const pollRef = useRef<{ ref: string; timer: ReturnType<typeof setTimeout> | null; alive: boolean } | null>(null);

  const stopPolling = useCallback(() => {
    if (pollRef.current) {
      pollRef.current.alive = false;
      if (pollRef.current.timer) clearTimeout(pollRef.current.timer);
      pollRef.current = null;
    }
  }, []);
  useEffect(() => stopPolling, [stopPolling]);

  const afterSuccess = useCallback(() => {
    setCard(EMPTY_CARD);
    setSelection(null);
    refresh();
    reloadSaved();
  }, [refresh, reloadSaved]);

  const succeed = useCallback(
    (extra?: Partial<PayStatus>) => {
      stopPolling();
      setStatus((s) => (s ? { ...s, ...extra, stage: "success" } : s));
      afterSuccess();
    },
    [afterSuccess, stopPolling],
  );

  const startPolling = useCallback(
    (reference: string) => {
      stopPolling();
      const startedAt = Date.now();
      const deadline = startedAt + POLL_WINDOW_MS;
      const state = { ref: reference, timer: null as ReturnType<typeof setTimeout> | null, alive: true };
      pollRef.current = state;
      setStatus((s) => (s ? { ...s, stage: "waiting", startedAt, deadline } : s));
      const tick = async () => {
        try {
          const p = await api.get<Payment>(`/payments/${reference}`);
          if (!state.alive) return;
          if (p.status === "success") return succeed();
          if (p.status === "failed" || p.status === "cancelled") {
            stopPolling();
            setStatus((s) => (s ? { ...s, stage: "failed", message: null } : s));
            return;
          }
        } catch {
          /* network blip: keep polling */
        }
        if (!state.alive) return;
        if (Date.now() >= deadline) {
          stopPolling();
          setStatus((s) => (s ? { ...s, stage: "timeout" } : s));
          return;
        }
        state.timer = setTimeout(tick, POLL_MS);
      };
      state.timer = setTimeout(tick, POLL_MS);
    },
    [stopPolling, succeed],
  );

  /* -------------------------------------------------------------- submit */
  const send = async (body: Body, attempt: Attempt) => {
    if (!plan) return;
    lastBody.current = { body, attempt };
    setSubmitting(true);
    try {
      const res = await api.post<CheckoutResponse>("/checkout", body);
      const pay = res.payment;
      if (res.next_action === "redirect" && res.redirect_url) {
        window.location.assign(res.redirect_url);
        return;
      }
      const methodCode = pay.payment_method ?? attempt.methodCode ?? null;
      const base: PayStatus = {
        stage: "waiting",
        channel: attempt.channel,
        reference: pay.reference,
        amount: pay.amount,
        currency: pay.currency,
        phone: pay.phone ?? attempt.phone ?? null,
        methodCode,
        methodName: attempt.channel === "card" && attempt.methodName ? attempt.methodName : networkName(methodCode),
        planName: plan.name,
        planType: plan.type,
        coins: (plan.coins ?? 0) + (plan.bonus_coins ?? 0),
        message: res.message,
      };
      if (pay.status === "success") {
        setStatus({ ...base, stage: "success" });
        afterSuccess();
      } else if (pay.status === "failed" || pay.status === "cancelled") {
        setStatus({ ...base, stage: "failed" });
      } else {
        setStatus(base);
        startPolling(pay.reference);
      }
    } catch (e) {
      const errs = e instanceof ApiError ? e.errors : undefined;
      if (errs?.phone) setPhoneError(errs.phone[0] ?? null);
      const cardErr = errs && Object.entries(errs).find(([k]) => k.startsWith("card"));
      if (cardErr) setCardErrors({ [cardErr[0].includes("exp") ? "expiry" : "number"]: cardErr[1][0] });
      if (errs?.saved_method_id) reloadSaved();
      if (!errs?.phone && !cardErr) toast.error(errorMessage(e));
      setStatus(null);
    } finally {
      setSubmitting(false);
    }
  };

  const submit = () => {
    if (!plan || !user) return;
    if (sel.kind === "saved" && selectedSaved) {
      return send(
        { plan_id: plan.id, saved_method_id: selectedSaved.id },
        {
          channel: selectedSaved.type,
          phone: selectedSaved.phone,
          methodCode: selectedSaved.type === "card" ? (selectedSaved.card_brand ?? selectedSaved.method_code) : selectedSaved.method_code,
          methodName: savedLabel(selectedSaved).title,
        },
      );
    }
    if (activeChannel === "mobile_money") {
      const normalized = normalizePhone(phoneValue);
      if (!normalized) return setPhoneError(t.phoneInvalid);
      const net = detectNetwork(normalized);
      if (!net) return setPhoneError(t.phoneUnknown);
      setPhoneError(null);
      return send(
        { plan_id: plan.id, channel: "mobile_money", phone: normalized, save },
        { channel: "mobile_money", phone: normalized, methodCode: net },
      );
    }
    // Card: validate here; the full number and CVC never leave this function.
    const errors: CardErrors = {};
    const brand = detectBrand(card.number);
    if (!brand) errors.number = cardDigits(card.number) ? t.cardUnsupported : t.cardInvalid;
    else if (!cardLengthOk(card.number, brand) || !luhnValid(card.number)) errors.number = t.cardInvalid;
    const exp = parseExpiry(card.expiry);
    if (!exp) errors.expiry = t.expiryInvalid;
    else if (expiryInPast(exp.month, exp.year)) errors.expiry = t.expiryPast;
    if (!/^\d{3}$/.test(card.cvc)) errors.cvc = t.cvcInvalid;
    setCardErrors(errors);
    if (Object.keys(errors).length || !brand || !exp) return;
    const last4 = cardDigits(card.number).slice(-4);
    // When a card provider is connected, its hosted fields / SDK tokenizes the card in the browser
    // (the number and CVC go straight to the provider) and returns a token. Send it as card.token:
    //   const token = await provider.tokenize({ number, cvc, exp_month, exp_year });
    // Until then only brand, last4 and expiry are sent. Never add the number or CVC to this payload.
    return send(
      {
        plan_id: plan.id,
        channel: "card",
        card: { brand, last4, exp_month: exp.month, exp_year: exp.year },
        save,
      },
      { channel: "card", methodCode: brand, methodName: `${networkName(brand)} •••• ${last4}` },
    );
  };

  const closeModal = () => {
    const wasWaiting = status?.stage === "waiting" && status.channel === "mobile_money";
    stopPolling();
    setStatus(null);
    if (wasWaiting) toast(t.closedWhilePending);
  };
  const retry = () => {
    stopPolling();
    setStatus(null);
    if (lastBody.current) send(lastBody.current.body, lastBody.current.attempt);
  };
  const checkAgain = () => status && startPolling(status.reference);

  /* -------------------------------------------------------------- render */
  const loadingSaved = !!user && savedReq.loading && !savedReq.data;
  const showNew = sel.kind === "new" || !saved.length;
  const payLabel = plan ? fmt(t.pay, { amount: formatMoney(plan.price, plan.currency) }) : t.payBare;
  const channelBlocked = sel.kind === "new" && (activeChannel === "mobile_money" ? !mmOk : !cardOk);

  return (
    <div className="mt-6">
      {loadingSaved ? (
        <div className="space-y-2">
          <div className="skeleton h-[62px] rounded-2xl" />
          <div className="skeleton h-[62px] rounded-2xl" />
        </div>
      ) : saved.length > 0 ? (
        <fieldset>
          <legend className="mb-2.5 text-[13px] font-semibold text-text-muted">{t.payWith}</legend>
          <div className="space-y-2" role="radiogroup">
            {saved.map((m) => {
              const label = savedLabel(m);
              const ok = usable(m);
              const channelOff = m.type === "card" ? !cardOk : !mmOk;
              const active = sel.kind === "saved" && sel.id === m.id;
              return (
                <button
                  key={m.id}
                  type="button"
                  role="radio"
                  aria-checked={active}
                  disabled={m.is_expired || channelOff}
                  onClick={() => {
                    if (ok) setSelection({ kind: "saved", id: m.id });
                    else {
                      // A card saved without a gateway token needs its details again.
                      setSelection({ kind: "new" });
                      setChannel(m.type);
                    }
                  }}
                  className={cn(
                    "flex w-full items-center gap-3 rounded-2xl border-2 p-3 text-left transition-all duration-150",
                    active ? "border-primary bg-primary/[0.07]" : "border-transparent bg-surface-2 hover:bg-surface-3",
                    (m.is_expired || channelOff) && "cursor-not-allowed opacity-50",
                  )}
                >
                  <SavedMethodIcon method={m} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[14px] font-bold tabular-nums">{label.title}</span>
                    <span className="block truncate text-xs text-text-muted">
                      {m.is_expired ? t.expired : channelOff ? t.comingSoon : !ok ? t.reenter : label.subtitle}
                      {m.is_default && !m.is_expired && <span className="font-semibold text-text"> · {t.default}</span>}
                    </span>
                  </span>
                  <Radio on={active} />
                </button>
              );
            })}
            <button
              type="button"
              role="radio"
              aria-checked={sel.kind === "new"}
              onClick={() => setSelection({ kind: "new" })}
              className={cn(
                "flex w-full items-center gap-3 rounded-2xl border-2 border-dashed p-3 text-left transition-all duration-150",
                sel.kind === "new" ? "border-primary bg-primary/[0.07]" : "border-border hover:bg-surface-2",
              )}
            >
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-surface-3 text-text-muted">
                <Icon name="plus" size={18} />
              </span>
              <span className="flex-1 text-[14px] font-bold">{t.addNew}</span>
              <Radio on={sel.kind === "new"} />
            </button>
          </div>
        </fieldset>
      ) : null}

      {showNew && !loadingSaved && (
        <div className={cn("animate-fade-in", saved.length > 0 && "mt-5")}>
          <div className="grid grid-cols-2 gap-1 rounded-2xl bg-surface-2 p-1" role="tablist" aria-label={t.payWith}>
            {(["mobile_money", "card"] as const).map((c) => {
              const ok = c === "mobile_money" ? mmOk : cardOk;
              const on = activeChannel === c;
              return (
                <button
                  key={c}
                  type="button"
                  role="tab"
                  aria-selected={on}
                  disabled={!ok}
                  onClick={() => setChannel(c)}
                  className={cn(
                    "relative flex flex-col items-center gap-0.5 rounded-xl px-2 py-2.5 transition-all duration-200",
                    on ? "bg-card text-text shadow-[0_4px_18px_-6px_rgba(0,0,0,0.45)] ring-1 ring-border" : "text-text-muted hover:text-text",
                    !ok && "cursor-not-allowed opacity-60 hover:text-text-muted",
                  )}
                >
                  <span className="flex items-center gap-1.5 text-[14px] font-bold">
                    <Icon name={c === "mobile_money" ? "phone" : "card"} size={16} className={on ? "text-primary" : ""} />
                    {t.channels[c]}
                  </span>
                  <span className="text-[11px] font-medium text-text-dim">{ok ? t.channelHints[c] : t.comingSoon}</span>
                </button>
              );
            })}
          </div>

          <div className="mt-4">
            {activeChannel === "mobile_money" ? (
              mmOk ? (
                <PhoneField
                  id="mm-phone"
                  value={phoneValue}
                  onChange={(v) => {
                    setPhone(v);
                    setPhoneError(null);
                  }}
                  error={phoneError}
                  hint={t.phoneHint}
                />
              ) : (
                <ComingSoon all={!cardOk} />
              )
            ) : cardOk ? (
              <>
                <CardFields
                  value={card}
                  onChange={(v) => {
                    setCard(v);
                    setCardErrors({});
                  }}
                  errors={cardErrors}
                />
                <p className="mt-3 flex items-start gap-1.5 text-xs leading-relaxed text-text-dim">
                  <Icon name="lock" size={13} className="mt-0.5 shrink-0" /> {t.cardPrivacy}
                </p>
              </>
            ) : (
              <ComingSoon all={!mmOk} />
            )}
          </div>

          {user && !channelBlocked && (
            <div className="mt-4 flex items-center gap-3 rounded-2xl bg-surface-2/60 px-3.5 py-3">
              <span className="min-w-0 flex-1">
                <span className="block text-[13px] font-bold">{t.save}</span>
                <span className="block text-[11px] text-text-dim">{t.saveHint}</span>
              </span>
              <Toggle checked={save} onChange={setSave} label={t.save} />
            </div>
          )}
        </div>
      )}

      {authLoading ? (
        <div className="skeleton mt-6 h-[52px] rounded-full" />
      ) : user ? (
        <Button
          onClick={submit}
          loading={submitting}
          disabled={!plan || loadingSaved || channelBlocked}
          size="lg"
          className="mt-6 h-[52px] w-full text-base shadow-[0_10px_30px_-10px_rgba(233,2,4,0.8)]"
        >
          {!submitting && <Icon name="lock" size={16} />} {payLabel}
        </Button>
      ) : (
        <Button href={loginHref} size="lg" className="mt-6 h-[52px] w-full text-base">
          {t.loginToPay}
        </Button>
      )}

      <p className="mt-3 flex items-center justify-center gap-1.5 text-[11px] font-semibold text-text-dim">
        <Icon name="shield" size={13} className="text-success" /> {t.secure}
      </p>
      {options?.demo && <p className="mt-1 text-center text-[11px] text-text-dim">{t.demo}</p>}

      <PaymentStatusModal status={status} onClose={closeModal} onRetry={retry} onCheckAgain={checkAgain} next={next} />
    </div>
  );
}

function Radio({ on }: { on: boolean }) {
  return (
    <span
      className={cn(
        "grid h-5 w-5 shrink-0 place-items-center rounded-full border-2 transition-colors",
        on ? "border-primary bg-primary text-white" : "border-text-dim/50",
      )}
      aria-hidden
    >
      {on && <Icon name="check" size={11} strokeWidth={3.4} />}
    </span>
  );
}

function ComingSoon({ all }: { all: boolean }) {
  const t = useT().user.pay;
  return (
    <div className="flex items-center gap-3 rounded-2xl border border-dashed border-border p-4 text-sm text-text-muted">
      <Icon name="clock" size={18} className="shrink-0 text-text-dim" />
      {all ? t.allSoon : t.channelSoon}
    </div>
  );
}

export function TermsLine() {
  const t = useT().user.vip;
  return (
    <p className="mt-4 text-center text-[11px] leading-relaxed text-text-dim">
      {t.agreePrefix}{" "}
      <Link href="/info/terms" className="underline hover:text-text">
        {t.terms}
      </Link>
      {t.noAutoRenew}
    </p>
  );
}
