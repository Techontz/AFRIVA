"use client";

import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { cn } from "@/lib/format";
import {
  NETWORKS,
  brandPossible,
  detectBrand,
  detectNetwork,
  formatExpiry,
  groupCard,
  localDigits,
  spaceLocal,
} from "@/lib/payments";
import { Icon } from "../../ui/Icon";
import { CardBrandMark, NetworkMark } from "./PayMarks";

const shell =
  "flex items-center rounded-2xl border bg-surface-2/60 transition-[border-color,box-shadow] duration-150 " +
  "focus-within:border-primary focus-within:ring-4 focus-within:ring-primary/15";

const bare =
  "pay-input w-0 min-w-0 flex-1 bg-transparent px-3.5 py-3 text-[15px] font-semibold tracking-wide text-text placeholder:font-medium placeholder:text-text-dim focus:outline-none focus-visible:outline-none";

function Label({ htmlFor, children }: { htmlFor: string; children: React.ReactNode }) {
  return (
    <label htmlFor={htmlFor} className="mb-1.5 block text-[13px] font-semibold text-text-muted">
      {children}
    </label>
  );
}

function Message({ error, hint }: { error?: string | null; hint?: React.ReactNode }) {
  if (error)
    return (
      <p className="mt-1.5 flex items-start gap-1.5 text-xs font-medium leading-snug text-danger animate-fade-in" role="alert">
        <Icon name="alert" size={13} className="shrink-0" /> {error}
      </p>
    );
  return hint ? <p className="mt-1.5 text-xs text-text-dim">{hint}</p> : null;
}

/**
 * Tanzanian mobile number with a fixed +255 prefix. Accepts "0754...", "754..." or "+255 754..."
 * and shows the network as soon as the prefix is known: there is no network picker.
 */
export function PhoneField({
  id,
  value,
  onChange,
  error,
  hint,
  autoFocus,
}: {
  id: string;
  value: string;
  onChange: (v: string) => void;
  error?: string | null;
  hint?: React.ReactNode;
  autoFocus?: boolean;
}) {
  const t = useT().user.pay;
  const network = detectNetwork(value);
  const digits = localDigits(value);
  const unknown = digits.length >= 2 && !network;
  return (
    <div>
      <Label htmlFor={id}>{t.phoneLabel}</Label>
      <div className={cn(shell, error ? "border-danger" : "border-border")}>
        <span className="flex items-center gap-1.5 self-stretch border-r border-border pl-3.5 pr-3 text-[15px] font-bold text-text-muted">
          <span aria-hidden className="relative h-3.5 w-5 overflow-hidden rounded-[3px]">
            <svg viewBox="0 0 30 20" className="h-full w-full">
              <path d="M0 0h30L0 20Z" fill="#1eb53a" />
              <path d="M30 0v20H0Z" fill="#00a3dd" />
              <path d="M0 20 30 0" stroke="#fcd116" strokeWidth="8" />
              <path d="M0 20 30 0" stroke="#000" strokeWidth="5" />
            </svg>
          </span>
          +255
        </span>
        <input
          id={id}
          type="tel"
          inputMode="tel"
          autoComplete="tel-national"
          autoFocus={autoFocus}
          placeholder="754 123 456"
          maxLength={17}
          value={value}
          aria-invalid={!!error}
          onChange={(e) => {
            const raw = e.target.value.replace(/[^\d+\s]/g, "");
            // "07..." and "+255 7..." are welcome: keep a bare 0 / +255 start while it is being typed,
            // then fold it into the fixed +255 prefix.
            onChange(/^\+?(0|2|25|255)?$/.test(raw.replace(/\s/g, "")) ? raw.trim() : spaceLocal(localDigits(raw)));
          }}
          onBlur={() => digits && onChange(spaceLocal(digits))}
          className={bare}
        />
        <span className="pr-2.5">
          {network ? (
            <span
              key={network}
              className="flex items-center gap-1.5 rounded-full bg-surface-3 p-1 text-xs font-bold text-text animate-pop-in min-[400px]:pr-2.5"
            >
              <NetworkMark code={network} size="sm" className="rounded-full" />
              <span className="hidden min-[400px]:inline">{NETWORKS[network].name}</span>
            </span>
          ) : (
            <Icon name="phone" size={18} className="mr-1 text-text-dim" />
          )}
        </span>
      </div>
      <Message
        error={error ?? (unknown ? t.phoneUnknown : null)}
        hint={
          network ? (
            <span className="flex items-center gap-1.5 font-semibold text-text-muted animate-fade-in">
              <Icon name="check" size={13} strokeWidth={3} className="text-success" />
              {fmt(t.detected, { network: NETWORKS[network].name })}
            </span>
          ) : (
            hint
          )
        }
      />
    </div>
  );
}

export interface CardDraft {
  number: string;
  expiry: string;
  cvc: string;
}

export type CardErrors = Partial<Record<keyof CardDraft, string | null>>;

/** Card number, expiry and CVC. Lives only in component state; nothing here is ever persisted. */
export function CardFields({
  value,
  onChange,
  errors,
}: {
  value: CardDraft;
  onChange: (v: CardDraft) => void;
  errors: CardErrors;
}) {
  const t = useT().user.pay;
  const brand = detectBrand(value.number);
  const unsupported = !brandPossible(value.number);
  return (
    <div className="space-y-3.5">
      <div>
        <Label htmlFor="cc-number">{t.cardNumber}</Label>
        <div className={cn(shell, errors.number || unsupported ? "border-danger" : "border-border")}>
          <input
            id="cc-number"
            inputMode="numeric"
            autoComplete="cc-number"
            placeholder="1234 5678 9012 3456"
            value={value.number}
            aria-invalid={!!errors.number || unsupported}
            onChange={(e) => onChange({ ...value, number: groupCard(e.target.value) })}
            className={cn(bare, "tabular-nums")}
          />
          <span className="flex items-center gap-1 pr-3">
            {brand ? (
              <CardBrandMark key={brand} brand={brand} className="animate-pop-in" />
            ) : (
              <>
                <CardBrandMark brand="visa" className="opacity-60" />
                <CardBrandMark brand="mastercard" className="opacity-60" />
              </>
            )}
          </span>
        </div>
        <Message error={errors.number ?? (unsupported ? t.cardUnsupported : null)} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div>
          <Label htmlFor="cc-exp">{t.expiry}</Label>
          <div className={cn(shell, errors.expiry ? "border-danger" : "border-border")}>
            <input
              id="cc-exp"
              inputMode="numeric"
              autoComplete="cc-exp"
              placeholder={t.expiryPlaceholder}
              value={value.expiry}
              aria-invalid={!!errors.expiry}
              onChange={(e) => onChange({ ...value, expiry: formatExpiry(e.target.value, value.expiry) })}
              className={cn(bare, "tabular-nums")}
            />
          </div>
          <Message error={errors.expiry} />
        </div>
        <div>
          <Label htmlFor="cc-cvc">{t.cvc}</Label>
          <div className={cn(shell, errors.cvc ? "border-danger" : "border-border")}>
            <input
              id="cc-cvc"
              inputMode="numeric"
              autoComplete="cc-csc"
              placeholder="123"
              maxLength={3}
              value={value.cvc}
              aria-invalid={!!errors.cvc}
              onChange={(e) => onChange({ ...value, cvc: e.target.value.replace(/\D/g, "").slice(0, 3) })}
              className={cn(bare, "tabular-nums")}
            />
            <Icon name="lock" size={16} className="mr-3.5 text-text-dim" />
          </div>
          <Message error={errors.cvc} />
        </div>
      </div>
    </div>
  );
}
