"use client";

import type { ReactNode } from "react";
import { useT } from "@/i18n/client";
import { cn } from "@/lib/format";
import { EmptyState, Pill, statusTone } from "./Feedback";

export function Spinner({ size = 20, className }: { size?: number; className?: string }) {
  const t = useT().common.feedback;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      className={cn("animate-spin", className)}
      role="status"
      aria-label={t.loading}
    >
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeOpacity="0.2" strokeWidth="3" fill="none" />
      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" strokeLinecap="round" fill="none" />
    </svg>
  );
}

export function ApiDownState({ className, action }: { className?: string; action?: ReactNode }) {
  const t = useT().common.feedback;
  return (
    <EmptyState
      className={className}
      icon="alert"
      title={t.apiDownTitle}
      description={t.apiDownBody}
      action={action}
    />
  );
}

export function StatusPill({ status }: { status: string | null | undefined }) {
  const t = useT().common.status;
  return <Pill tone={statusTone(status)}>{status ? (t[status] ?? status) : "-"}</Pill>;
}
