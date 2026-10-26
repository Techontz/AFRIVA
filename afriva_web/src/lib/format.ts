import clsx, { type ClassValue } from "clsx";
import { getLang, type Vars } from "./i18n";

/** Date locale for the active UI language. Browser only; server renders stay English. */
function dateLocale(): string {
  return typeof window !== "undefined" && getLang() === "sw" ? "sw-TZ" : "en-GB";
}

type Translate = (text: string, vars?: Vars) => string;

const english: Translate = (text, vars) =>
  vars ? text.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k] ?? "") : m)) : text;

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

export function formatDate(value: string | null | undefined, withTime = false): string {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(dateLocale(), {
    day: "numeric",
    month: "short",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
}

export function shortDate(value: string): string {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(dateLocale(), { day: "numeric", month: "short" });
}

export function initials(name: string | null | undefined): string {
  return (name || "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join("");
}

/** Pass `t` from useT() to get the summary in the active language. */
export function planSummary(
  plan: {
    type: string;
    duration_days: number | null;
    episode_quota: number | null;
    coins: number | null;
    bonus_coins: number | null;
  },
  t: Translate = english,
): string {
  switch (plan.type) {
    case "weekly":
    case "monthly":
    case "yearly":
      return t("{n} days unlimited VIP", { n: plan.duration_days ?? "" }).trim();
    case "episodes":
      return t("Unlock any {n} episodes", { n: plan.episode_quota ?? 0 });
    case "coins":
      return plan.bonus_coins
        ? t("{n} coins + {bonus} bonus", { n: formatNumber(plan.coins), bonus: plan.bonus_coins })
        : t("{n} coins", { n: formatNumber(plan.coins) });
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
