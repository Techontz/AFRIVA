import type { Metadata } from "next";
import { Suspense } from "react";
import { PortalShell, type NavItem } from "@/components/portal/PortalShell";
import { PortalFallback } from "@/components/portal/PortalFallback";
import { StudioNotice } from "@/components/studio/StudioNotice";

export const metadata: Metadata = { title: { default: "Studio", template: "%s · AFRIVA Studio" } };

const nav: NavItem[] = [
  { href: "/studio", label: "Overview", icon: "chart", exact: true },
  { href: "/studio/dramas", label: "My works", icon: "film" },
  { href: "/studio/analytics", label: "Analytics", icon: "trophy" },
  { href: "/studio/earnings", label: "Earnings", icon: "wallet" },
  { href: "/studio/payouts", label: "Payouts", icon: "payout" },
  { href: "/studio/agreement", label: "Revenue agreement", icon: "shield" },
  { href: "/studio/profile", label: "Profile", icon: "building" },
];

export default function StudioLayout({ children }: LayoutProps<"/studio">) {
  return (
    <Suspense fallback={<PortalFallback />}>
      <PortalShell role="company" title="Studio" nav={nav}>
        <StudioNotice />
        {children}
      </PortalShell>
    </Suspense>
  );
}
