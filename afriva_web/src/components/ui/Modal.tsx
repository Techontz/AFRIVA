"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";
import { Icon } from "./Icon";

export function Modal({
  open,
  onClose,
  title,
  children,
  size = "md",
  className,
  hideClose,
}: {
  open: boolean;
  onClose: () => void;
  title?: ReactNode;
  children: ReactNode;
  size?: "sm" | "md" | "lg" | "xl";
  className?: string;
  hideClose?: boolean;
}) {
  const t = useT();
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const prev = document.activeElement as HTMLElement | null;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", onKey);
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    panelRef.current?.focus();
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
      prev?.focus?.();
    };
  }, [open, onClose]);

  if (!open || typeof document === "undefined") return null;

  const widths = { sm: "max-w-sm", md: "max-w-lg", lg: "max-w-2xl", xl: "max-w-4xl" };

  const host = (document.querySelector(".site-dark") as HTMLElement | null) ?? document.body;
  return createPortal(
    <div className="fixed inset-0 z-[100] flex items-end justify-center sm:items-center sm:p-4">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm animate-fade-in" onClick={onClose} />
      <div
        ref={panelRef}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        className={cn(
          "relative w-full max-h-[92dvh] overflow-y-auto rounded-t-3xl sm:rounded-3xl border border-border bg-surface shadow-2xl outline-none animate-pop-in pb-safe",
          widths[size],
          className,
        )}
      >
        {(title || !hideClose) && (
          <div className="sticky top-0 z-10 flex items-center justify-between gap-4 bg-surface/95 px-5 pt-5 pb-3 backdrop-blur">
            <h2 className="text-lg font-bold">{typeof title === "string" ? t(title) : title}</h2>
            {!hideClose && (
              <button
                onClick={onClose}
                className="grid h-9 w-9 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                aria-label={t("Close")}
              >
                <Icon name="x" />
              </button>
            )}
          </div>
        )}
        <div className="px-5 pb-5">{children}</div>
      </div>
    </div>,
    host,
  );
}

export function ConfirmModal({
  open,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = "Confirm",
  danger,
  loading,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  danger?: boolean;
  loading?: boolean;
}) {
  const t = useT();
  return (
    <Modal open={open} onClose={onClose} title={title} size="sm">
      <div className="text-sm text-text-muted">{typeof message === "string" ? t(message) : message}</div>
      <div className="mt-6 flex justify-end gap-2">
        <button onClick={onClose} className="h-10 rounded-full px-5 text-sm font-semibold text-text-muted hover:bg-surface-2">
          {t("Cancel")}
        </button>
        <button
          onClick={onConfirm}
          disabled={loading}
          className={cn(
            "h-10 rounded-full px-5 text-sm font-semibold text-white disabled:opacity-60",
            danger ? "bg-danger hover:brightness-110" : "bg-primary hover:brightness-110",
          )}
        >
          {loading ? t("Working…") : t(confirmLabel)}
        </button>
      </div>
    </Modal>
  );
}
