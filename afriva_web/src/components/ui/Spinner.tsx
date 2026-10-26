"use client";

import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";

export function Spinner({ size = 20, className }: { size?: number; className?: string }) {
  const t = useT();
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      className={cn("animate-spin", className)}
      role="status"
      aria-label={t("Loading")}
    >
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeOpacity="0.2" strokeWidth="3" fill="none" />
      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" strokeLinecap="round" fill="none" />
    </svg>
  );
}
