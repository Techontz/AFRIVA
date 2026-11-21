import clsx, { type ClassValue } from "clsx";
import { DEFAULT_LOCALE, intlLocale, type Locale } from "@/i18n/config";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { fmt } from "@/i18n/format";

export const cn = (...args: ClassValue[]) => clsx(args);

export function formatMoney(amount: number | string | null | undefined, currency = "TZS"): string {
  const n = Number(amount ?? 0);
  return `${Math.round(n).toLocaleString("en-US")} ${currency}`;
}

export function formatCompact(n: number | string | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 1_000_000_000) return `${(v / 1_000_000_000).toFixed(1).replace(/\.0$/, "")}B`;
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
  if (v >= 1_000) return `${(v / 1_000).toFixed(1).replace(/\.0$/, "")}K`;
  return String(Math.round(v));
}

export function formatNumber(n: number | string | null | undefined): string {
  return Number(n ?? 0).toLocaleString("en-US");
}

export function formatDuration(seconds: number | null | undefined): string {
  const s = Math.max(0, Math.round(Number(seconds ?? 0)));
  const m = Math.floor(s / 60);
  return `${m}:${String(s % 60).padStart(2, "0")}`;
}

export function formatDate(value: string | null | undefined, withTime = false, locale: Locale = DEFAULT_LOCALE): string {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(intlLocale(locale), {
    day: "numeric",
    month: "short",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
}

export function shortDate(value: string, locale: Locale = DEFAULT_LOCALE): string {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(intlLocale(locale), { day: "numeric", month: "short" });
}

export function initials(name: string | null | undefined): string {
  return (name || "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join("");
}

/**
 * How much a subscription saves against buying the next shorter one repeatedly
 * (monthly vs 4 weeks, yearly vs 12 months). Null when there is no saving.
 */
export function planSavings(
  plan: { type: string; price: number; duration_days: number | null },
  all: { type: string; price: number; duration_days: number | null; is_active?: boolean }[],
): number | null {
  const days = plan.duration_days ?? 0;
  if (!["weekly", "monthly", "yearly"].includes(plan.type) || days <= 0) return null;
  const shorter = all
    .filter((p) => ["weekly", "monthly", "yearly"].includes(p.type) && p.is_active !== false)
    .filter((p) => (p.duration_days ?? 0) > 0 && (p.duration_days ?? 0) < days)
    .sort((a, b) => (b.duration_days ?? 0) - (a.duration_days ?? 0))[0];
  if (!shorter) return null;
  const units = Math.round(days / (shorter.duration_days ?? 1));
  const save = units * shorter.price - plan.price;
  return units > 1 && save > 0 ? save : null;
}

export function planSummary(
  plan: {
    type: string;
    duration_days: number | null;
    episode_quota: number | null;
    coins: number | null;
    bonus_coins: number | null;
  },
  t: Dictionary["common"]["plan"],
): string {
  switch (plan.type) {
    case "weekly":
    case "monthly":
    case "yearly":
      return fmt(t.unlimited, { n: plan.duration_days ?? "" }).trim();
    case "episodes":
      return fmt(t.episodes, { n: plan.episode_quota ?? 0 });
    case "coins":
      return fmt(t.coins, { n: formatNumber(plan.coins) }) + (plan.bonus_coins ? fmt(t.bonus, { n: plan.bonus_coins }) : "");
    default:
      return "";
  }
}

/** Reads the first finite number among candidate keys of a loosely-typed object. */
export function pickNum(obj: unknown, ...keys: string[]): number {
  if (!obj || typeof obj !== "object") return 0;
  const o = obj as Record<string, unknown>;
  for (const k of keys) {
    const v = o[k];
    if (v !== undefined && v !== null && v !== "" && Number.isFinite(Number(v))) return Number(v);
  }
  return 0;
}

/** Normalises a chart series of `{date|day|label, <value keys>}` into `{date, value}`. */
export function toSeries(raw: unknown, ...valueKeys: string[]): { date: string; value: number }[] {
  if (!Array.isArray(raw)) {
    if (raw && typeof raw === "object") {
      // `{ "2026-10-01": 1200, ... }`
      return Object.entries(raw as Record<string, unknown>).map(([date, v]) => ({
        date,
        value: typeof v === "object" ? pickNum(v, ...valueKeys) : Number(v) || 0,
      }));
    }
    return [];
  }
  return raw.map((p) => {
    const o = (p ?? {}) as Record<string, unknown>;
    return {
      date: String(o.date ?? o.day ?? o.label ?? o.period_date ?? ""),
      value: pickNum(o, ...valueKeys, "value", "total", "amount", "count"),
    };
  });
}

/**
 * Returns `v` only if it is a same-origin path. Rejects protocol-relative
 * (`//x`), backslash (`/\x`, treated as `//x` by browsers) and whitespace /
 * control characters (stripped by URL parsers) to prevent open redirects.
 */
export function safeNextPath(v: string | null | undefined): string | null {
  if (!v || !v.startsWith("/") || v.startsWith("//")) return null;
  if (/[\\\s\u0000-\u001f]/.test(v)) return null;
  return v;
}
