"use client";

import { useSyncExternalStore } from "react";
import { useT } from "@/i18n/client";
import { cn } from "@/lib/format";
import { DEFAULT_THEME, THEME_COOKIE, type Theme } from "@/lib/theme";
import { Icon } from "./ui/Icon";

function readTheme(): Theme {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

function subscribe(onChange: () => void) {
  const observer = new MutationObserver(onChange);
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
  return () => observer.disconnect();
}

export function useTheme(): [Theme, (t: Theme) => void] {
  const theme = useSyncExternalStore(subscribe, readTheme, () => DEFAULT_THEME);
  const set = (next: Theme) => {
    const secure = window.location.protocol === "https:" ? "; Secure" : "";
    document.cookie = `${THEME_COOKIE}=${next}; Path=/; Max-Age=${60 * 60 * 24 * 365}; SameSite=Lax${secure}`;
    document.documentElement.dataset.theme = next;
  };
  return [theme, set];
}

/** Sun/moon switch. `withLabel` shows the target mode as text (menus, sidebars). */
export function ThemeToggle({ className, withLabel }: { className?: string; withLabel?: boolean }) {
  const [theme, setTheme] = useTheme();
  const t = useT().common.theme;
  const next: Theme = theme === "dark" ? "light" : "dark";
  const label = next === "light" ? t.toLight : t.toDark;
  return (
    <button
      type="button"
      onClick={() => setTheme(next)}
      aria-label={label}
      title={label}
      className={cn("flex items-center gap-2 transition", className)}
    >
      <Icon name={theme === "dark" ? "sun" : "moon"} size={withLabel ? 17 : 19} />
      {withLabel && <span>{next === "light" ? t.light : t.dark}</span>}
    </button>
  );
}
