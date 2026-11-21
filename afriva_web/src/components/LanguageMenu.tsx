"use client";

import { useRouter } from "@/lib/navigation";
import { useEffect, useRef, useState, useTransition } from "react";
import { LANG_COOKIE, LOCALES, LOCALE_LABELS, stripLocale, type Locale } from "@/i18n/config";
import { useLocale, useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { cn } from "@/lib/format";
import { Icon } from "./ui/Icon";

/** Close a popover on outside click / Escape. */
export function useDismiss(open: boolean, close: () => void, ref: React.RefObject<HTMLElement | null>) {
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) close();
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && close();
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, close, ref]);
}

function persistLocale(code: Locale) {
  const secure = window.location.protocol === "https:" ? "; Secure" : "";
  document.cookie = `${LANG_COOKIE}=${code}; Path=/; Max-Age=${60 * 60 * 24 * 365}; SameSite=Lax${secure}`;
  document.documentElement.lang = code;
}

export function LanguageMenu({
  className,
  buttonClassName = "py-2 text-[17px] font-normal text-white hover:text-primary xl:text-xl",
  up,
}: {
  className?: string;
  buttonClassName?: string;
  /** Open the list above the button (e.g. at the bottom of a sidebar). */
  up?: boolean;
}) {
  const locale = useLocale();
  const t = useT().common;
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useDismiss(open, () => setOpen(false), ref);

  const choose = (code: Locale) => {
    setOpen(false);
    if (code === locale) return;
    persistLocale(code);
    // An /en or /sw prefix would keep winning over the cookie, so drop it when switching.
    const { pathname, search, hash } = window.location;
    const bare = stripLocale(pathname);
    startTransition(() => {
      if (bare !== pathname) router.replace(`${bare}${search}${hash}`);
      else router.refresh();
    });
  };

  return (
    <div ref={ref} className={cn("relative", className)}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={fmt(t.languageCurrent, { name: LOCALE_LABELS[locale] })}
        className={cn("flex items-center gap-1.5 transition", pending && "opacity-60", buttonClassName)}
      >
        {LOCALE_LABELS[locale]}
        <Icon name="chevron-down" size={16} />
      </button>
      {open && (
        <ul
          role="listbox"
          aria-label={t.language}
          className={cn(
            "absolute left-0 z-50 w-40 overflow-hidden rounded-xl border border-border bg-surface p-1 shadow-2xl animate-pop-in",
            up ? "bottom-full mb-2" : "top-12",
          )}
        >
          {LOCALES.map((code) => (
            <li key={code}>
              <button
                role="option"
                aria-selected={code === locale}
                onClick={() => choose(code)}
                className="flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm text-text-muted transition hover:bg-surface-2 hover:text-text"
              >
                {LOCALE_LABELS[code]}
                {code === locale && <Icon name="check" size={15} className="text-primary" />}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
