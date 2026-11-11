/**
 * Viewer checkout helpers: Tanzanian mobile money numbers and card checks.
 *
 * Card numbers and CVCs are only ever validated here, in the browser. They are never sent to the
 * Afriva API, never logged and never written to any storage.
 */

import type { Payment, Subscription } from "./types";

export type Channel = "mobile_money" | "card";
export type CardBrand = "visa" | "mastercard";
export type NetworkCode = "mpesa" | "airtelmoney" | "tigopesa" | "halopesa" | "tpesa";

export interface CheckoutOptions {
  mobile_money: { available: boolean; networks: { code: string; name: string; available: boolean }[] };
  card: { available: boolean; brands: { code: string; name: string; available: boolean }[] };
  demo: boolean;
}

export interface SavedMethod {
  id: number;
  type: Channel;
  method_code: string;
  network: string | null;
  phone: string | null;
  card_brand: string | null;
  card_last4: string | null;
  card_exp_month: number | null;
  card_exp_year: number | null;
  is_default: boolean;
  is_expired: boolean;
  one_tap: boolean;
  last_used_at: string | null;
}

export interface CheckoutResponse {
  payment: Pick<Payment, "reference" | "status" | "amount" | "currency" | "phone"> & {
    payment_method?: string | null;
  };
  message: string;
  next_action: "none" | "await_ussd" | "redirect";
  redirect_url?: string | null;
  subscription?: Subscription | null;
  user_coins?: number;
}

/* ---------------------------------------------------------------- Mobile money */

export const NETWORKS: Record<NetworkCode, { name: string; color: string; short: string }> = {
  mpesa: { name: "M-Pesa", color: "#e60000", short: "M" },
  airtelmoney: { name: "Airtel Money", color: "#ff0a1e", short: "A" },
  tigopesa: { name: "Mixx by Yas", color: "#1c3fa8", short: "Y" },
  halopesa: { name: "HaloPesa", color: "#f57c00", short: "H" },
  tpesa: { name: "T-Pesa", color: "#0b6fb8", short: "T" },
};

/** Number prefix after 255 => network (mirrors the API's MobileNetwork::PREFIXES). */
const PREFIXES: Record<string, NetworkCode> = {
  "74": "mpesa", "75": "mpesa", "76": "mpesa", "79": "mpesa",
  "68": "airtelmoney", "69": "airtelmoney", "78": "airtelmoney",
  "65": "tigopesa", "67": "tigopesa", "71": "tigopesa", "77": "tigopesa",
  "61": "halopesa", "62": "halopesa",
  "73": "tpesa",
};

/**
 * The nine local digits (7XXXXXXXX) from whatever the viewer typed:
 * "0754 123 456", "754123456", "+255 754 123 456" or "255754123456".
 */
export function localDigits(input: string): string {
  let d = input.replace(/\D/g, "");
  if (d.startsWith("255")) d = d.slice(3);
  else if (d.startsWith("0")) d = d.slice(1);
  return d.slice(0, 9);
}

/** "255754123456" when the number is a complete TZ mobile number, otherwise null. */
export function normalizePhone(input: string): string | null {
  const d = localDigits(input);
  return /^[67]\d{8}$/.test(d) ? `255${d}` : null;
}

/** Network for the number as soon as the first two local digits are known. */
export function detectNetwork(input: string): NetworkCode | null {
  const d = localDigits(input);
  return d.length >= 2 ? (PREFIXES[d.slice(0, 2)] ?? null) : null;
}

/** "754 123 456" (spaced local digits, for the +255 input). */
export function spaceLocal(digits: string): string {
  return [digits.slice(0, 3), digits.slice(3, 6), digits.slice(6, 9)].filter(Boolean).join(" ");
}

/** "+255 754 123 456" for display. */
export function formatPhone(phone: string | null | undefined, mask = false): string {
  if (!phone) return "";
  const d = localDigits(phone);
  if (d.length !== 9) return phone;
  return `+255 ${d.slice(0, 3)} ${mask ? "•••" : d.slice(3, 6)} ${d.slice(6)}`;
}

export function networkName(code: string | null | undefined, fallback?: string | null): string {
  if (code && code in NETWORKS) return NETWORKS[code as NetworkCode].name;
  if (code === "visa") return "Visa";
  if (code === "mastercard") return "Mastercard";
  return fallback || (code ?? "").replace(/_/g, " ");
}

/* ---------------------------------------------------------------- Cards */

export function cardDigits(input: string): string {
  return input.replace(/\D/g, "").slice(0, 19);
}

/** Only Visa and Mastercard are accepted. */
export function detectBrand(input: string): CardBrand | null {
  const d = cardDigits(input);
  if (d.startsWith("4")) return "visa";
  const two = Number(d.slice(0, 2));
  if (d.length >= 2 && two >= 51 && two <= 55) return "mastercard";
  const four = Number(d.slice(0, 4));
  if (d.length >= 4 && four >= 2221 && four <= 2720) return "mastercard";
  return null;
}

/** True while what has been typed could still become a Visa or Mastercard number. */
export function brandPossible(input: string): boolean {
  const d = cardDigits(input);
  if (!d) return true;
  if (d[0] === "4") return true;
  if (d[0] === "5") return d.length < 2 || detectBrand(d) === "mastercard";
  if (d[0] === "2") {
    if (d.length < 4) {
      const lo = "2221".slice(0, d.length);
      const hi = "2720".slice(0, d.length);
      return d >= lo && d <= hi;
    }
    return detectBrand(d) === "mastercard";
  }
  return false;
}

export function luhnValid(input: string): boolean {
  const d = cardDigits(input);
  if (d.length < 12) return false;
  let sum = 0;
  let dbl = false;
  for (let i = d.length - 1; i >= 0; i--) {
    let n = d.charCodeAt(i) - 48;
    if (dbl) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    dbl = !dbl;
  }
  return sum % 10 === 0;
}

export function cardLengthOk(input: string, brand: CardBrand | null): boolean {
  const n = cardDigits(input).length;
  if (brand === "mastercard") return n === 16;
  if (brand === "visa") return n === 13 || n === 16 || n === 19;
  return false;
}

/** "4242 4242 4242 4242" */
export function groupCard(input: string): string {
  return cardDigits(input).replace(/(.{4})/g, "$1 ").trim();
}

/** "MM / YY" while typing. */
export function formatExpiry(input: string, prev: string): string {
  let d = input.replace(/\D/g, "").slice(0, 4);
  // "4" => "04": a single month digit above 1 cannot start a two digit month.
  if (d.length === 1 && Number(d) > 1) d = `0${d}`;
  // Deleting the separator should delete the month digit before it.
  if (prev.endsWith(" / ") && input.length < prev.length) d = d.slice(0, 1);
  return d.length >= 2 ? `${d.slice(0, 2)} / ${d.slice(2)}` : d;
}

export function parseExpiry(value: string): { month: number; year: number } | null {
  const d = value.replace(/\D/g, "");
  if (d.length !== 4) return null;
  const month = Number(d.slice(0, 2));
  const year = 2000 + Number(d.slice(2));
  if (month < 1 || month > 12) return null;
  return { month, year };
}

export function expiryInPast(month: number, year: number, now = new Date()): boolean {
  return year < now.getFullYear() || (year === now.getFullYear() && month < now.getMonth() + 1);
}

export function savedLabel(m: SavedMethod, mask = true): { title: string; subtitle: string } {
  if (m.type === "card") {
    const exp =
      m.card_exp_month && m.card_exp_year
        ? `${String(m.card_exp_month).padStart(2, "0")}/${String(m.card_exp_year).slice(-2)}`
        : "";
    return { title: `${networkName(m.card_brand ?? m.method_code)} •••• ${m.card_last4 ?? ""}`, subtitle: exp };
  }
  return { title: formatPhone(m.phone, mask), subtitle: networkName(m.method_code, m.network) };
}
