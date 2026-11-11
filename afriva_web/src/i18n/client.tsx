"use client";

import { createContext, useContext, useMemo } from "react";
import { DEFAULT_LOCALE, type Locale } from "./config";
import type { Dictionary } from "./dictionaries/en";

type Ctx = { locale: Locale; t: Partial<Dictionary> };

const I18nContext = createContext<Ctx>({ locale: DEFAULT_LOCALE, t: {} });

/**
 * Provides dictionary namespaces to client components. Nested providers merge,
 * so each layout only ships the namespaces its subtree needs.
 */
export function I18nProvider({
  locale,
  messages,
  children,
}: {
  locale: Locale;
  messages: Partial<Dictionary>;
  children: React.ReactNode;
}) {
  const parent = useContext(I18nContext);
  const value = useMemo(() => ({ locale, t: { ...parent.t, ...messages } }), [locale, parent.t, messages]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

/** Dictionary for client components. Only namespaces provided by an ancestor layout are present. */
export function useT(): Dictionary {
  return useContext(I18nContext).t as Dictionary;
}

export function useLocale(): Locale {
  return useContext(I18nContext).locale;
}
