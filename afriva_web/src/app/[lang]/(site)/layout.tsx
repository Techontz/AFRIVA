import { BottomNav } from "@/components/site/BottomNav";
import { Footer } from "@/components/site/Footer";
import { Header } from "@/components/site/Header";
import { I18nProvider } from "@/i18n/client";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { getDict, getLocale } from "@/i18n/server";

/** Only the `site` sections client components read; page copy (info pages, headings) stays on the server. */
function clientSite({ card, featured, search, drama, episodes }: Dictionary["site"]) {
  return { card, featured, search, drama, episodes } as Dictionary["site"];
}

export default async function SiteLayout({ children }: { children: React.ReactNode }) {
  const [locale, t] = await Promise.all([getLocale(), getDict()]);
  return (
    <I18nProvider locale={locale} messages={{ site: clientSite(t.site), user: t.user, creator: t.creator }}>
      <div className="site-shell flex min-h-full flex-1 flex-col bg-bg text-text has-[[data-tabbar]]:pb-(--tabbar-h)">
        <Header />
        <main id="main" className="min-h-dvh flex-1">
          {children}
        </main>
        <Footer />
        <BottomNav />
      </div>
    </I18nProvider>
  );
}
