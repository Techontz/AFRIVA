import type { Metadata } from "next";
import { Suspense } from "react";
import { PortalShell, type NavItem } from "@/components/portal/PortalShell";
import { PortalFallback } from "@/components/portal/PortalFallback";

export const metadata: Metadata = { title: { default: "Msimamizi", template: "%s · AFRIVA Admin" } };

// Scope §05/§06 navigation; each item is shown only to staff roles with the permission (SPEC §8.6).
const nav: NavItem[] = [
  { href: "/admin", label: "Overview", icon: "chart", exact: true, perm: "dashboard" },
  { href: "/admin/reviews", label: "Review", icon: "shield", perm: "review" },
  { href: "/admin/dramas", label: "Series & Episodes", icon: "film", perm: ["content", "review", "publish"] },
  { href: "/admin/videos", label: "Video Library", icon: "play", perm: "content" },
  { href: "/admin/companies", label: "Creators", icon: "building", perm: "creators" },
  { href: "/admin/payments", label: "Transactions", icon: "wallet", perm: "finance" },
  { href: "/admin/analytics", label: "Analytics", icon: "trophy", perm: "analytics" },
  { href: "/admin/reports", label: "Reports", icon: "alert", perm: "reports" },
  { href: "/admin/users", label: "Users", icon: "users", perm: "users" },
  { href: "/admin/settings", label: "Settings", icon: "settings", perm: "settings" },
  { href: "/admin/categories", label: "Categories", icon: "tag", perm: "content", section: "More" },
  { href: "/admin/plans", label: "Plans", icon: "crown", perm: "finance" },
  { href: "/admin/payment-methods", label: "Payment Methods", icon: "card", perm: "finance" },
  { href: "/admin/payouts", label: "Creator payouts", icon: "payout", perm: "finance" },
  { href: "/admin/staff", label: "Staff", icon: "user", perm: "staff" },
  { href: "/admin/audit-logs", label: "Audit log", icon: "history", perm: "audit" },
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
