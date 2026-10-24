"use client";

import type { ReactNode } from "react";
import { cn } from "@/lib/format";
import type { PageMeta } from "@/lib/types";
import { EmptyState, Skeleton } from "../ui/Feedback";
import { Icon, type IconName } from "../ui/Icon";

export function PageHeader({
  title,
  description,
  actions,
  back,
}: {
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  back?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div className="min-w-0">
        {back && <div className="mb-2">{back}</div>}
        <h1 className="text-2xl font-extrabold tracking-tight sm:text-[28px]">{title}</h1>
        {description && <p className="mt-1 text-sm text-text-muted">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function Card({ children, className, title, actions }: { children: ReactNode; className?: string; title?: ReactNode; actions?: ReactNode }) {
  return (
    <section className={cn("rounded-2xl border border-border bg-surface p-5", className)}>
      {(title || actions) && (
        <div className="mb-4 flex items-center justify-between gap-3">
          {title && <h2 className="text-[15px] font-bold">{title}</h2>}
          {actions}
        </div>
      )}
      {children}
    </section>
  );
}

export function StatCard({
  label,
  value,
  icon,
  hint,
  accent = "brand",
  loading,
}: {
  label: string;
  value: ReactNode;
  icon: IconName;
  hint?: ReactNode;
  accent?: "brand" | "gold" | "success" | "info";
  loading?: boolean;
}) {
  const accents = {
    brand: "bg-primary/15 text-primary",
    gold: "bg-primary/15 text-primary",
    success: "bg-success/15 text-success",
    info: "bg-sky-500/15 text-sky-400",
  };
  return (
    <div className="rounded-2xl border border-border bg-surface p-4 sm:p-5 transition-colors hover:border-[#3A3A3A]">
      <div className="flex items-start justify-between gap-2">
        <p className="text-xs font-semibold uppercase tracking-wider text-text-dim">{label}</p>
        <span className={cn("grid h-9 w-9 place-items-center rounded-xl", accents[accent])}>
          <Icon name={icon} size={18} />
        </span>
      </div>
      {loading ? (
        <Skeleton className="mt-2 h-8 w-28" />
      ) : (
        <p className="mt-1 text-xl font-extrabold tracking-tight sm:text-2xl">{value}</p>
      )}
      {hint && <p className="mt-1 text-xs text-text-muted">{hint}</p>}
    </div>
  );
}

export interface Column<T> {
  key: string;
  header: ReactNode;
  render: (row: T) => ReactNode;
  className?: string;
}

export function DataTable<T>({
  columns,
  rows,
  loading,
  rowKey,
  empty,
  onRowClick,
}: {
  columns: Column<T>[];
  rows: T[];
  loading?: boolean;
  rowKey: (row: T) => string | number;
  empty?: ReactNode;
  onRowClick?: (row: T) => void;
}) {
  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-surface">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead>
            <tr className="border-b border-border text-[11px] uppercase tracking-wider text-text-dim">
              {columns.map((c) => (
                <th key={c.key} className={cn("px-4 py-3 font-semibold", c.className)}>
                  {c.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading
              ? Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i} className="border-b border-border/60 last:border-0">
                    {columns.map((c) => (
                      <td key={c.key} className="px-4 py-3.5">
                        <Skeleton className="h-4 w-full max-w-[140px]" />
                      </td>
                    ))}
                  </tr>
                ))
              : rows.map((row) => (
                  <tr
                    key={rowKey(row)}
                    onClick={onRowClick ? () => onRowClick(row) : undefined}
                    className={cn(
                      "border-b border-border/60 last:border-0 transition-colors hover:bg-surface-2/60",
                      onRowClick && "cursor-pointer",
                    )}
                  >
                    {columns.map((c) => (
                      <td key={c.key} className={cn("px-4 py-3 align-middle", c.className)}>
                        {c.render(row)}
                      </td>
                    ))}
                  </tr>
                ))}
          </tbody>
        </table>
      </div>
      {!loading && rows.length === 0 && (
        <div className="p-4">{empty ?? <EmptyState icon="list" title="Nothing here yet" className="border-0 bg-transparent" />}</div>
      )}
    </div>
  );
}

export function Pagination({ meta, onPage }: { meta: PageMeta | null; onPage: (p: number) => void }) {
  if (!meta || meta.last_page <= 1) return null;
  const { current_page: page, last_page: last } = meta;
  return (
    <div className="mt-4 flex items-center justify-between gap-3 text-sm">
      <p className="text-text-dim">
        Page {page} of {last} · {meta.total.toLocaleString()} total
      </p>
      <div className="flex gap-2">
        <button
          disabled={page <= 1}
          onClick={() => onPage(page - 1)}
          className="grid h-9 w-9 place-items-center rounded-full border border-border text-text-muted transition hover:bg-surface-2 disabled:opacity-40"
          aria-label="Previous page"
        >
          <Icon name="chevron-left" size={18} />
        </button>
        <button
          disabled={page >= last}
          onClick={() => onPage(page + 1)}
          className="grid h-9 w-9 place-items-center rounded-full border border-border text-text-muted transition hover:bg-surface-2 disabled:opacity-40"
          aria-label="Next page"
        >
          <Icon name="chevron-right" size={18} />
        </button>
      </div>
    </div>
  );
}

export function Toolbar({ children }: { children: ReactNode }) {
  return <div className="mb-4 flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">{children}</div>;
}

export function SearchBox({ value, onChange, placeholder = "Search…" }: { value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <div className="relative w-full sm:w-72">
      <Icon name="search" size={17} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-text-dim" />
      <input
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="h-10 w-full rounded-full border border-border bg-surface pl-10 pr-4 text-sm placeholder:text-text-dim focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/25"
      />
    </div>
  );
}

export function Thumb({ src, alt, className }: { src?: string | null; alt: string; className?: string }) {
  return (
    <div className={cn("relative aspect-[3/4] w-10 shrink-0 overflow-hidden rounded-md bg-surface-2", className)}>
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt={alt} className="h-full w-full object-cover" loading="lazy" />
      ) : (
        <div className="grid h-full w-full place-items-center text-text-dim">
          <Icon name="film" size={16} />
        </div>
      )}
    </div>
  );
}
