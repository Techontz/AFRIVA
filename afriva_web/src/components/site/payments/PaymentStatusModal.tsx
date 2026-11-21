"use client";

import type { CSSProperties } from "react";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { cn, formatMoney } from "@/lib/format";
import { formatPhone } from "@/lib/payments";
import { Button } from "../../ui/Button";
import { Spinner } from "../../ui/Feedback";
import { Icon } from "../../ui/Icon";
import { Modal } from "../../ui/Modal";
import { CardBrandMark, MastercardMark, NetworkMark, VisaMark } from "./PayMarks";

/** redirecting: on the way to the card partner's hosted page. cancelled: back from it without paying. */
export type PayStage = "waiting" | "success" | "failed" | "timeout" | "redirecting" | "cancelled";

export interface PayStatus {
  stage: PayStage;
  channel: "mobile_money" | "card";
  reference: string;
  amount: number;
  currency: string;
  /** Normalised 255... number (mobile money). */
  phone?: string | null;
  /** Network or card brand code (mpesa, visa...). */
  methodCode?: string | null;
  methodName?: string | null;
  planName?: string | null;
  planType?: string | null;
  coins?: number | null;
  message?: string | null;
  /** Back from the card partner's hosted page (confirming a payment made there). */
  returned?: boolean;
  /** Polling deadline (ms epoch) for the countdown bar. */
  deadline?: number;
  startedAt?: number;
}

const BURST = Array.from({ length: 14 }, (_, i) => {
  const a = (i / 14) * Math.PI * 2;
  const r = 70 + (i % 3) * 16;
  return {
    dx: `${Math.round(Math.cos(a) * r)}px`,
    dy: `${Math.round(Math.sin(a) * r)}px`,
    color: ["#e90204", "#22c55e", "#fcd116", "#ffffff"][i % 4],
    delay: `${(i % 4) * 40}ms`,
    size: i % 2 ? 6 : 4,
  };
});

export function PaymentStatusModal({
  status,
  onClose,
  onRetry,
  onCheckAgain,
  next,
}: {
  status: PayStatus | null;
  onClose: () => void;
  onRetry: () => void;
  onCheckAgain: () => void;
  next?: string;
}) {
  const t = useT().user.pay;
  if (!status) return null;
  const amount = status.amount > 0 ? formatMoney(status.amount, status.currency) : "";
  const redirecting = status.stage === "redirecting";
  return (
    <Modal open onClose={redirecting ? () => {} : onClose} hideClose size="sm" className="overflow-x-hidden">
      <div className="relative pt-6 text-center">
        {!redirecting && (
          <button
            onClick={onClose}
            className="absolute -top-1 right-0 grid h-9 w-9 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
            aria-label={t.close}
          >
            <Icon name="x" size={18} />
          </button>
        )}

        {redirecting && (
          <div className="py-4 animate-fade-in" aria-live="polite">
            <div className="relative mx-auto grid h-24 w-24 place-items-center">
              <span className="absolute inset-0 rounded-full border-2 border-primary/15" />
              <span className="absolute inset-0 rounded-full border-2 border-transparent border-t-primary animate-spin" />
              <span className="grid h-16 w-16 place-items-center rounded-full bg-primary/12 text-primary">
                <Icon name="lock" size={28} strokeWidth={1.9} />
              </span>
            </div>
            <h2 className="mt-5 text-xl font-extrabold">{t.redirectingTitle}</h2>
            <p className="mx-auto mt-1.5 max-w-[300px] text-sm text-text-muted">{t.redirectingBody}</p>
            <div className="mt-5 flex items-center justify-center gap-2">
              <VisaMark />
              <MastercardMark />
            </div>
            {amount && <p className="mt-4 text-[13px] font-bold tabular-nums text-text-muted">{amount}</p>}
          </div>
        )}

        {status.stage === "cancelled" && (
          <div className="animate-fade-in" aria-live="polite">
            <div className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-surface-2 text-text-muted animate-scale-in">
              <Icon name="card" size={32} strokeWidth={1.9} />
            </div>
            <h2 className="mt-5 text-xl font-extrabold">{t.cancelledTitle}</h2>
            <p className="mx-auto mt-1.5 max-w-[320px] text-sm text-text-muted">{t.cancelledBody}</p>
            <p className="mt-3 text-[11px] text-text-dim">
              {t.reference} <span className="font-mono">{status.reference}</span>
            </p>
            <div className="mt-6 flex flex-col gap-2">
              <Button size="lg" className="w-full" onClick={onRetry}>
                <Icon name="refresh" size={16} /> {t.tryAgain}
              </Button>
              <Button variant="ghost" className="w-full" onClick={onClose}>
                {t.close}
              </Button>
            </div>
          </div>
        )}

        {status.stage === "waiting" && status.channel === "mobile_money" && (
          <div className="animate-fade-in" aria-live="polite">
            <div className="relative mx-auto grid h-28 w-28 place-items-center">
              {[0, 0.8, 1.6].map((d) => (
                <span
                  key={d}
                  className="absolute inset-3 rounded-full border-2 border-primary/50 animate-ripple"
                  style={{ animationDelay: `${d}s` }}
                />
              ))}
              <span className="relative grid h-[72px] w-[72px] place-items-center rounded-[26px] bg-brand text-white shadow-[0_12px_40px_-8px_rgba(233,2,4,0.7)]">
                <Icon name="phone" size={34} strokeWidth={1.8} />
              </span>
            </div>
            <h2 className="mt-5 text-[22px] font-extrabold tracking-tight">{t.checkPhone}</h2>
            <p className="mt-1.5 text-sm text-text-muted">{t.sentTo}</p>
            <div className="mx-auto mt-3 inline-flex items-center gap-2.5 rounded-2xl bg-surface-2 py-2 pl-2 pr-4">
              <NetworkMark code={status.methodCode} />
              <span className="text-left">
                <span className="block text-[15px] font-extrabold tabular-nums">{formatPhone(status.phone)}</span>
                <span className="block text-xs font-semibold text-text-muted">{status.methodName}</span>
              </span>
            </div>

            <ol className="mx-auto mt-6 max-w-[300px] space-y-2.5 text-left text-sm">
              {[t.step1, fmt(t.step2, { network: status.methodName ?? "" }), t.step3].map((s, i) => (
                <li key={i} className="flex items-start gap-3">
                  <span className="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-primary/15 text-xs font-extrabold text-primary">
                    {i + 1}
                  </span>
                  <span className="pt-0.5 text-text-muted">{s}</span>
                </li>
              ))}
            </ol>

            <div className="mt-6 flex items-start gap-3 rounded-2xl border border-border bg-surface-2/50 p-3.5 text-left">
              <Icon name="shield" size={18} className="mt-0.5 shrink-0 text-success" />
              <p className="text-[13px] leading-relaxed text-text-muted">{t.pinNote}</p>
            </div>

            <Countdown status={status} />
            <p className="mt-2 text-[11px] text-text-dim">{t.noPrompt}</p>
            <Button variant="ghost" className="mt-4 w-full" onClick={onClose}>
              {t.otherMethod}
            </Button>
          </div>
        )}

        {status.stage === "waiting" && status.channel === "card" && (
          <div className="py-4 animate-fade-in" aria-live="polite">
            <div className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-primary/12 text-primary">
              <Spinner size={34} />
            </div>
            <h2 className="mt-5 text-xl font-extrabold">{t.confirming}</h2>
            <p className="mx-auto mt-1.5 max-w-[300px] text-sm text-text-muted">{status.returned ? t.confirmingReturnHint : t.confirmingHint}</p>
            <Countdown status={status} />
          </div>
        )}

        {status.stage === "success" && (
          <div aria-live="polite">
            <div className="relative mx-auto grid h-28 w-28 place-items-center">
              {BURST.map((b, i) => (
                <span
                  key={i}
                  className="absolute left-1/2 top-1/2 -ml-[3px] -mt-[3px] rounded-full animate-burst"
                  style={
                    {
                      "--dx": b.dx,
                      "--dy": b.dy,
                      width: b.size,
                      height: b.size,
                      background: b.color,
                      animationDelay: b.delay,
                    } as CSSProperties
                  }
                />
              ))}
              <span className="absolute inset-2 rounded-full bg-success/15 animate-scale-in" />
              <span className="relative grid h-[72px] w-[72px] place-items-center rounded-full bg-success text-white shadow-[0_12px_40px_-8px_rgba(34,197,94,0.7)] animate-scale-in">
                <svg viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="m5 12.5 4.5 4.5L19 7.5" strokeDasharray="30" className="animate-draw" />
                </svg>
              </span>
            </div>
            <h2 className="mt-5 text-[22px] font-extrabold tracking-tight animate-pop-in">{t.successTitle}</h2>
            <p className="mx-auto mt-1.5 max-w-[300px] text-sm text-text-muted animate-pop-in">
              {status.planType === "coins"
                ? fmt(t.successCoins, { n: status.coins ?? 0 })
                : status.planType === "episodes"
                  ? t.successEpisodes
                  : status.planType
                    ? t.successVip
                    : t.successGeneric}
            </p>
            <Receipt
              status={status}
              rows={[
                [t.plan, status.planName ?? "-"],
                [t.amount, amount || "-"],
                [t.reference, status.reference],
              ]}
            />
            <div className="mt-6 flex flex-col gap-2">
              <Button href={next || "/"} size="lg" className="w-full">
                <Icon name="play" size={15} /> {next ? t.continueWatching : t.startWatching}
              </Button>
              <Button href="/account?tab=payments" variant="ghost" className="w-full">
                {t.viewHistory}
              </Button>
            </div>
          </div>
        )}

        {(status.stage === "failed" || status.stage === "timeout") && (
          <div className="animate-fade-in" aria-live="polite">
            <div
              className={cn(
                "mx-auto grid h-20 w-20 place-items-center rounded-full animate-scale-in",
                status.stage === "failed" ? "bg-danger/15 text-danger" : "bg-surface-2 text-text-muted",
              )}
            >
              <Icon name={status.stage === "failed" ? "x" : "clock"} size={34} strokeWidth={2.2} />
            </div>
            <h2 className="mt-5 text-xl font-extrabold">{status.stage === "failed" ? t.failedTitle : t.timeoutTitle}</h2>
            <p className="mx-auto mt-1.5 max-w-[320px] text-sm text-text-muted">
              {status.stage === "failed" ? status.message || t.failedBody : t.timeoutBody}
            </p>
            <p className="mt-3 text-[11px] text-text-dim">
              {t.reference} <span className="font-mono">{status.reference}</span>
            </p>
            <div className="mt-6 flex flex-col gap-2">
              {status.stage === "timeout" && (
                <Button size="lg" className="w-full" onClick={onCheckAgain}>
                  <Icon name="refresh" size={16} /> {t.checkAgain}
                </Button>
              )}
              <Button size="lg" variant={status.stage === "timeout" ? "secondary" : "primary"} className="w-full" onClick={onRetry}>
                {amount ? fmt(t.tryAgainAmount, { amount }) : t.tryAgain}
              </Button>
              <Button variant="ghost" className="w-full" onClick={onClose}>
                {t.otherMethod}
              </Button>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}

function Receipt({ rows, status }: { rows: [string, string][]; status: PayStatus }) {
  const t = useT().user.pay;
  return (
    <dl className="mt-6 divide-y divide-border rounded-2xl bg-surface-2/60 px-4 text-left text-sm animate-pop-in">
      {rows.map(([k, v]) => (
        <div key={k} className="flex items-center justify-between gap-4 py-2.5">
          <dt className="shrink-0 text-text-dim">{k}</dt>
          <dd className={cn("min-w-0 truncate font-semibold", k === t.reference && "font-mono text-xs")}>{v}</dd>
        </div>
      ))}
      <div className="flex items-center justify-between gap-4 py-2.5">
        <dt className="shrink-0 text-text-dim">{t.method}</dt>
        <dd className="flex min-w-0 items-center gap-2.5">
          {status.channel === "card" ? (
            <CardBrandMark brand={status.methodCode} className="h-5 w-8" />
          ) : (
            <NetworkMark code={status.methodCode} size="sm" />
          )}
          <span className="min-w-0 text-right">
            <span className="block truncate font-semibold tabular-nums">
              {status.channel === "card" ? status.methodName : formatPhone(status.phone)}
            </span>
            {status.channel === "mobile_money" && (
              <span className="block truncate text-[11px] text-text-dim">{status.methodName}</span>
            )}
          </span>
        </dd>
      </div>
    </dl>
  );
}

/** Thin progress bar that drains over the polling window. */
function Countdown({ status }: { status: PayStatus }) {
  const t = useT().user.pay;
  const total = status.deadline && status.startedAt ? status.deadline - status.startedAt : 0;
  return (
    <div className="mt-6">
      <div className="flex items-center justify-center gap-2 text-xs font-semibold text-text-muted">
        <Spinner size={14} /> {t.waiting}
      </div>
      {total > 0 && (
        <div className="mx-auto mt-2.5 h-1 max-w-[220px] overflow-hidden rounded-full bg-surface-3">
          <div
            key={status.startedAt}
            className="h-full origin-left rounded-full bg-primary"
            style={{ animation: `pay-drain ${total}ms linear both` }}
          />
        </div>
      )}
    </div>
  );
}
