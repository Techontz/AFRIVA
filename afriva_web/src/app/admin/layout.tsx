import type { Metadata } from "next";
import { Suspense } from "react";
import { PortalShell, type NavItem } from "@/components/portal/PortalShell";
import { PortalFallback } from "@/components/portal/PortalFallback";

export const metadata: Metadata = { title: { default: "Admin", template: "%s · Afriva Admin" } };

const nav: NavItem[] = [
  { href: "/admin", label: "Dashboard", icon: "chart", exact: true },
  { href: "/admin/companies", label: "Companies", icon: "building" },
  { href: "/admin/dramas", label: "Dramas", icon: "film" },
  { href: "/admin/plans", label: "Plans", icon: "crown" },
  { href: "/admin/categories", label: "Categories", icon: "tag" },
  { href: "/admin/payment-methods", label: "Payment Methods", icon: "card" },
  { href: "/admin/users", label: "Users", icon: "users" },
  { href: "/admin/payments", label: "Payments", icon: "wallet" },
  { href: "/admin/payouts", label: "Payouts", icon: "payout" },
  { href: "/admin/settings", label: "Settings", icon: "settings" },
];

export default function AdminLayout({ children }: LayoutProps<"/admin">) {
  return (
    <Suspense fallback={<PortalFallback />}>
      <PortalShell role="super_admin" title="Admin" nav={nav}>
        {children}
      </PortalShell>
    </Suspense>
  );
}
