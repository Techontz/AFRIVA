import type { ReactNode } from "react";
import { cn } from "@/lib/format";
import { T } from "@/lib/i18n";
import { Icon, type IconName } from "./Icon";

export { Spinner } from "./Spinner";

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("skeleton rounded-md", className)} aria-hidden="true" />;
}

export function EmptyState({
  icon = "film",
  title,
  description,
  action,
  className,
}: {
  icon?: IconName;
  title: ReactNode;
  description?: ReactNode;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center text-center gap-3 rounded-2xl border border-dashed border-border bg-surface/40 px-6 py-14",
        className,
      )}
    >
      <div className="grid h-14 w-14 place-items-center rounded-full bg-surface-2 text-text-muted">
        <Icon name={icon} size={26} />
      </div>
      <h3 className="text-base font-bold">
        {typeof title === "string" ? <T>{title}</T> : title}
      </h3>
      {description && (
        <p className="max-w-sm text-sm text-text-muted">{typeof description === "string" ? <T>{description}</T> : description}</p>
      )}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}

export function ApiDownState({ className, action }: { className?: string; action?: ReactNode }) {
  return (
    <EmptyState
      className={className}
      icon="alert"
      title="We can't reach Afriva right now"
      description="Our servers didn't respond. Check your connection or try again in a moment."
      action={action}
    />
  );
}

const tones = {
  neutral: "bg-surface-2 text-text-muted",
  brand: "bg-primary/15 text-primary",
  gold: "bg-text/10 text-text",
  success: "bg-success/15 text-success",
  danger: "bg-danger/15 text-danger",
  info: "bg-sky-500/15 text-sky-400",
} as const;

export type Tone = keyof typeof tones;

export function Pill({ tone = "neutral", children, className }: { tone?: Tone; children: ReactNode; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-semibold capitalize whitespace-nowrap",
        tones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

export function statusTone(status: string | null | undefined): Tone {
  switch (status) {
    case "success":
    case "active":
    case "published":
    case "paid":
      return "success";
    case "pending":
    case "draft":
      return "gold";
    case "failed":
    case "suspended":
    case "cancelled":
    case "expired":
      return "danger";
    default:
      return "neutral";
  }
}

export function StatusPill({ status }: { status: string | null | undefined }) {
  return <Pill tone={statusTone(status)}>{status ? <T>{status}</T> : "-"}</Pill>;
}
