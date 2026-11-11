export const LOCALES = ["en", "sw"] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = "en";
export const LANG_COOKIE = "afriva_lang";

export const LOCALE_LABELS: Record<Locale, string> = { en: "English", sw: "Kiswahili" };

export function isLocale(v: unknown): v is Locale {
  return v === "en" || v === "sw";
}

/** A browser pathname without its optional /en or /sw prefix. */
export function stripLocale(pathname: string): string {
  return pathname.replace(/^\/(en|sw)(?=\/|$)/, "") || "/";
}

/** BCP 47 tag used for Intl date/number formatting. */
export function intlLocale(locale: Locale): string {
  return locale === "sw" ? "sw-TZ" : "en-GB";
}
