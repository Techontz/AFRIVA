"use client";

import { useT } from "@/lib/i18n";
import { Button } from "../ui/Button";
import { ApiDownState } from "../ui/Feedback";

export function LoadError({ onRetry }: { onRetry: () => void }) {
  const t = useT();
  return (
    <ApiDownState
      action={
        <Button variant="secondary" size="sm" onClick={onRetry}>
          {t("Try again")}
        </Button>
      }
    />
  );
}

/** Coerces a string form value into a number or null. */
export function numOrNull(v: string): number | null {
  if (v === "" || v === null || v === undefined) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export function str(v: unknown): string {
  return v === null || v === undefined ? "" : String(v);
}

export function methodLabel(p: { payment_method_code?: string; payment_method?: unknown }): string {
  const m = p.payment_method;
  if (m && typeof m === "object" && "name" in m) return String((m as { name: string }).name);
  if (typeof m === "string") return m;
  return p.payment_method_code ?? "-";
}
