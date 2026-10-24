import type { Metadata } from "next";
import { Suspense } from "react";
import { PortalShell, type NavItem } from "@/components/portal/PortalShell";
import { PortalFallback } from "@/components/portal/PortalFallback";

export const metadata: Metadata = { title: { default: "Studio", template: "%s · Afriva Studio" } };

const nav: NavItem[] = [
  { href: "/studio", label: "Dashboard", icon: "chart", exact: true },
  { href: "/studio/dramas", label: "My Dramas", icon: "film" },
  { href: "/studio/earnings", label: "Earnings", icon: "wallet" },
  { href: "/studio/payouts", label: "Payouts", icon: "payout" },
  { href: "/studio/profile", label: "Profile", icon: "building" },
];

export default function StudioLayout({ children }: LayoutProps<"/studio">) {
  return (
    <Suspense fallback={<PortalFallback />}>
      <PortalShell role="company" title="Studio" nav={nav}>
        {children}
      </PortalShell>
    </Suspense>
  );
}
