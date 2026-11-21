import type { Metadata, Viewport } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import { Providers } from "@/components/Providers";
import { Suspense } from "react";
import { NavProgress } from "@/components/ui/NavProgress";
import { LOCALES } from "@/i18n/config";
import { I18nProvider } from "@/i18n/client";
import { getDict, getLocale } from "@/i18n/server";
import { DEFAULT_THEME, THEME_SCRIPT } from "@/lib/theme";
import "../globals.css";

const jakarta = Plus_Jakarta_Sans({
  variable: "--font-jakarta",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/+$/, "");

export function generateStaticParams() {
  return LOCALES.map((lang) => ({ lang }));
}

export async function generateMetadata(): Promise<Metadata> {
  const t = await getDict();
  return {
    // Absolute base for Open Graph / canonical URLs (falls back to Next's default when unset).
    metadataBase: siteUrl ? new URL(siteUrl) : undefined,
    title: { default: t.common.meta.title, template: "%s · Afriva" },
    description: t.common.meta.description,
    applicationName: "Afriva",
    openGraph: { siteName: "Afriva", type: "website", locale: (await getLocale()) === "sw" ? "sw_TZ" : "en_GB" },
  };
}

export const viewport: Viewport = {
  themeColor: "#000000",
  colorScheme: "dark light",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default async function RootLayout({ children }: LayoutProps<"/[lang]">) {
  const [locale, t] = await Promise.all([getLocale(), getDict()]);
  return (
    // data-theme is rewritten from the theme cookie by THEME_SCRIPT before paint.
    <html lang={locale} data-theme={DEFAULT_THEME} suppressHydrationWarning className={`${jakarta.variable} h-full antialiased`}>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body className="min-h-full flex flex-col bg-bg text-text">
        <I18nProvider locale={locale} messages={{ common: t.common, errors: t.errors }}>
          <Suspense fallback={null}>
            <NavProgress />
          </Suspense>
          <Providers>{children}</Providers>
        </I18nProvider>
      </body>
    </html>
  );
}
