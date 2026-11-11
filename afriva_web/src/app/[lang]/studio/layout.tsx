import type { Metadata } from "next";
import { Suspense } from "react";
import { PortalShell, type NavItem } from "@/components/portal/PortalShell";
import { PortalFallback } from "@/components/portal/PortalFallback";
import { StudioGate } from "@/components/studio/StudioGate";
import { I18nProvider } from "@/i18n/client";
import { getDict, getLocale } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = (await getDict()).studio.meta;
  return {
    title: { default: t.title, template: t.template },
    robots: { index: false, follow: false },
  };
}

export default async function StudioLayout({ children }: LayoutProps<"/[lang]/studio">) {
  const [locale, t] = await Promise.all([getLocale(), getDict()]);
  const n = t.studio.nav;
  const nav: NavItem[] = [
    { href: "/studio", label: n.dashboard, icon: "chart", exact: true },
    { href: "/studio/dramas", label: n.dramas, icon: "film" },
    { href: "/studio/earnings", label: n.earnings, icon: "wallet" },
    { href: "/studio/payouts", label: n.payouts, icon: "payout" },
    { href: "/studio/profile", label: n.profile, icon: "building" },
  ];
  return (
    <I18nProvider locale={locale} messages={{ portal: t.portal, studio: t.studio, creator: t.creator }}>
      <Suspense fallback={<PortalFallback />}>
        <PortalShell role="company" title={t.studio.meta.title} nav={nav}>
          <StudioGate>{children}</StudioGate>
        </PortalShell>
      </Suspense>
    </I18nProvider>
  );
}
