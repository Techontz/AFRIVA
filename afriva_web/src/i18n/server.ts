import { lang } from "next/root-params";
import { DEFAULT_LOCALE, isLocale, type Locale } from "./config";
import type { Dictionary } from "./dictionaries/en";

const loaders: Record<Locale, () => Promise<Dictionary>> = {
  en: () => import("./dictionaries/en").then((m) => m.default),
  sw: () => import("./dictionaries/sw").then((m) => m.default),
};

/** Current locale from the `[lang]` root segment (set by the proxy from the `afriva_lang` cookie). */
export async function getLocale(): Promise<Locale> {
  const l = await lang();
  return isLocale(l) ? l : DEFAULT_LOCALE;
}

export async function getDict(): Promise<Dictionary> {
  return loaders[await getLocale()]();
}
