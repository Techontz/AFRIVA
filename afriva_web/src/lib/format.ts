import clsx, { type ClassValue } from "clsx";

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
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
}

export function shortDate(value: string): string {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

export function initials(name: string | null | undefined): string {
  return (name || "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join("");
}

export function planSummary(plan: {
  type: string;
  duration_days: number | null;
  episode_quota: number | null;
  coins: number | null;
  bonus_coins: number | null;
}): string {
  switch (plan.type) {
    case "weekly":
    case "monthly":
    case "yearly":
      return `${plan.duration_days ?? ""} days unlimited VIP`.trim();
    case "episodes":
      return `Unlock any ${plan.episode_quota ?? 0} episodes`;
    case "coins":
      return `${formatNumber(plan.coins)} coins${plan.bonus_coins ? ` + ${plan.bonus_coins} bonus` : ""}`;
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
