"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Suspense } from "react";
import { useT } from "@/i18n/client";
import { stripLocale } from "@/i18n/config";
import { useAuth } from "@/lib/auth";
import { cn } from "@/lib/format";
import { Icon, type IconName } from "../ui/Icon";

function Tabs() {
  const path = stripLocale(usePathname());
  const { user } = useAuth();
  const { nav, header } = useT().common;

  // The episode player needs the whole screen.
  if (/^\/drama\/[^/]+\/ep\//.test(path)) return null;

  const tabs: { href: string; label: string; icon: IconName }[] = [
    { href: "/", label: nav.home, icon: "home" },
    { href: "/browse", label: nav.browse, icon: "grid" },
    { href: "/foryou", label: nav.forYouShort, icon: "play" },
    { href: "/rankings", label: nav.rankings, icon: "trophy" },
    { href: user ? "/account" : "/login", label: user ? nav.account : header.logIn, icon: "user" },
  ];

  return (
    <nav
      data-tabbar
      aria-label={nav.mobile}
      className="fixed inset-x-0 bottom-0 z-40 bg-bg/80 pb-[env(safe-area-inset-bottom)] backdrop-blur-2xl backdrop-saturate-150 lg:hidden"
    >
      <ul className="grid h-14 grid-cols-5">
        {tabs.map((tab) => {
          const active = tab.href === "/" ? path === "/" : path.startsWith(tab.href);
          return (
            <li key={tab.href}>
              <Link
                href={tab.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "flex h-full flex-col items-center justify-center gap-0.5 px-1 text-[10.5px] font-medium transition-colors",
                  active ? "text-primary" : "text-text-dim hover:text-text",
                )}
              >
                <Icon name={tab.icon} size={21} />
                <span className="max-w-full truncate">{tab.label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

/** Slim tab bar for phones and tablets; fixed, so it never moves the page while it streams in. */
export function BottomNav() {
  return (
    <Suspense fallback={null}>
      <Tabs />
    </Suspense>
  );
}
