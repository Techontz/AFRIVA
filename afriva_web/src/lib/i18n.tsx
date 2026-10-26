"use client";

import { createContext, useCallback, useContext, useEffect, useSyncExternalStore } from "react";
import { common } from "./sw/common";
import { site } from "./sw/site";
import { admin } from "./sw/admin";
import { studio } from "./sw/studio";

/**
 * UI translations. The whole interface is Kiswahili (scope §01); English is only an
 * optional fallback. The English text is the key: `t("My account")` returns the
 * Kiswahili entry when Kiswahili is active (the default), otherwise the English as written.
 * Placeholders use `{name}`: `t("{n} episodes", { n: 12 })`.
 */
export type Lang = "en" | "sw";
export type Vars = Record<string, string | number | null | undefined>;

export const DEFAULT_LANG: Lang = "sw";

export const LANGS: { code: Lang; short: string; label: string }[] = [
  { code: "sw", short: "SW", label: "Kiswahili" },
  { code: "en", short: "EN", label: "English" },
];

const SW: Record<string, string> = { ...common, ...site, ...admin, ...studio };
const STORAGE_KEY = "afriva_lang";

// Mirrors the provider's language for code outside React (formatters, API helpers).
let currentLang: Lang = DEFAULT_LANG;

export function translate(lang: Lang, text: string, vars?: Vars): string {
  const s = lang === "sw" ? (SW[text] ?? text) : text;
  if (!vars) return s;
  return s.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k] ?? "") : m));
}

/** Translate with the active language, for code that can't use hooks. */
export function tNow(text: string, vars?: Vars): string {
  return translate(currentLang, text, vars);
}

export function getLang(): Lang {
  return currentLang;
}

const LangContext = createContext<{ lang: Lang; setLang: (l: Lang) => void }>({ lang: DEFAULT_LANG, setLang: () => {} });

// The saved choice lives in localStorage (with an in-memory fallback when storage is blocked).
let memoryLang: Lang = DEFAULT_LANG;
const listeners = new Set<() => void>();

function readSaved(): Lang {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "sw" || saved === "en") return saved;
  } catch {}
  return memoryLang;
}

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  window.addEventListener("storage", onChange);
  return () => {
    listeners.delete(onChange);
    window.removeEventListener("storage", onChange);
  };
}

// Snapshots also update currentLang, so tNow()/getLang() agree with the render in progress.
// The server snapshot (used for SSR and hydration) is always Kiswahili.
const getSnapshot = (): Lang => (currentLang = readSaved());
const getServerSnapshot = (): Lang => (currentLang = DEFAULT_LANG);

function saveLang(l: Lang) {
  memoryLang = l;
  try {
    localStorage.setItem(STORAGE_KEY, l);
  } catch {}
  listeners.forEach((fn) => fn());
}

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const lang = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  return <LangContext.Provider value={{ lang, setLang: saveLang }}>{children}</LangContext.Provider>;
}

export function useLang() {
  return useContext(LangContext);
}

export function useT() {
  const { lang } = useContext(LangContext);
  return useCallback((text: string, vars?: Vars) => translate(lang, text, vars), [lang]);
}

/** Translated text for server components: `<T>Trending now</T>`. */
export function T({ children, vars }: { children: string; vars?: Vars }) {
  const t = useT();
  return <>{t(children, vars)}</>;
}
