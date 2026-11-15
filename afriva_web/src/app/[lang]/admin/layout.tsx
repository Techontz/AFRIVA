import type { Metadata } from "next";
import { Suspense } from "react";
import { PortalShell, type NavItem } from "@/components/portal/PortalShell";
import { PortalFallback } from "@/components/portal/PortalFallback";
import { I18nProvider } from "@/i18n/client";
import { getDict, getLocale } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = (await getDict()).admin.meta;
  return {
    title: { default: t.title, template: t.template },
    robots: { index: false, follow: false },
  };
}

export default async function AdminLayout({ children }: LayoutProps<"/[lang]/admin">) {
  const [locale, t] = await Promise.all([getLocale(), getDict()]);
  const n = t.admin.nav;
  const nav: NavItem[] = [
    { href: "/admin", label: n.dashboard, icon: "chart", exact: true },
    { href: "/admin/companies", label: n.companies, icon: "building" },
    { href: "/admin/dramas", label: n.dramas, icon: "film" },
    { href: "/admin/plans", label: n.plans, icon: "crown" },
    { href: "/admin/categories", label: n.categories, icon: "tag" },
    { href: "/admin/payment-methods", label: n.paymentMethods, icon: "card" },
    { href: "/admin/users", label: n.users, icon: "users" },
    { href: "/admin/payments", label: n.payments, icon: "wallet" },
    { href: "/admin/payouts", label: n.payouts, icon: "payout" },
    { href: "/admin/infrastructure", label: n.infrastructure, icon: "server" },
    { href: "/admin/settings", label: n.settings, icon: "settings" },
  ];
  return (
    <I18nProvider locale={locale} messages={{ portal: t.portal, admin: t.admin, creator: t.creator }}>
      <Suspense fallback={<PortalFallback />}>
        <PortalShell role="super_admin" title={t.admin.meta.title} nav={nav}>
          {children}
        </PortalShell>
      </Suspense>
    </I18nProvider>
  );
}
