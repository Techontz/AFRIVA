"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { useAuth } from "@/lib/auth";
import { cn, initials } from "@/lib/format";
import { LANGS, useLang, useT } from "@/lib/i18n";
import { STAFF_ROLE_LABEL } from "@/lib/portal";
import type { Role, StaffPermission, User } from "@/lib/types";
import { RoleGuard } from "../RoleGuard";
import { NoAccess } from "./ScopeKit";
import { Icon, type IconName } from "../ui/Icon";
import { Logo } from "../ui/Logo";

export interface NavItem {
  href: string;
  label: string;
  icon: IconName;
  exact?: boolean;
  /** Staff permission(s) needed (any of). Items the user can't use are hidden and their routes blocked. */
  perm?: StaffPermission | StaffPermission[];
  /** Optional group heading shown above this item. */
  section?: string;
}

function allowed(user: User | null, item: NavItem): boolean {
  if (!item.perm || user?.role !== "super_admin") return true;
  const perms = Array.isArray(item.perm) ? item.perm : [item.perm];
  return perms.some((p) => user.permissions?.includes(p));
}

/** The nav item a path belongs to (longest matching href). */
function matchItem(nav: NavItem[], pathname: string): NavItem | undefined {
  return nav
    .filter((i) => pathname === i.href || (!i.exact && pathname.startsWith(i.href + "/")))
    .sort((a, b) => b.href.length - a.href.length)[0];
}

export function PortalShell({
  role,
  title,
  nav,
  children,
}: {
  role: Role;
  title: string;
  nav: NavItem[];
  children: React.ReactNode;
}) {
  return (
    <RoleGuard roles={[role]}>
      <ShellInner title={title} nav={nav}>
        {children}
      </ShellInner>
    </RoleGuard>
  );
}

function ShellInner({ title, nav, children }: { title: string; nav: NavItem[]; children: React.ReactNode }) {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const [open, setOpen] = useState(false);
  const t = useT();

  const visible = nav.filter((item) => allowed(user, item));
  const current = matchItem(nav, pathname);
  const blocked = !!current && !allowed(user, current);
  const isActive = (item: NavItem) => current?.href === item.href;

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="flex h-16 items-center justify-between px-5">
        <Link href="/" className="flex items-center gap-2" onClick={() => setOpen(false)}>
          <Logo size={24} />
        </Link>
        <span className="rounded-full bg-surface-2 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-text-muted">
          {t(title)}
        </span>
      </div>
      <nav className="flex-1 space-y-0.5 overflow-y-auto px-3 py-2" aria-label={t("{title} navigation", { title: t(title) })}>
        {visible.map((item) => {
          const active = isActive(item);
          return (
            <div key={item.href}>
            {item.section && (
              <p className="px-3 pb-1 pt-4 text-[10px] font-bold uppercase tracking-wider text-text-dim">{t(item.section)}</p>
            )}
            <Link
              href={item.href}
              onClick={() => setOpen(false)}
              aria-current={active ? "page" : undefined}
              className={cn(
                "group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold transition-colors duration-150",
                active ? "bg-primary/12 text-text" : "text-text-muted hover:bg-surface-2 hover:text-text",
              )}
            >
              <span
                className={cn(
                  "grid h-8 w-8 place-items-center rounded-lg transition-colors",
                  active ? "bg-primary text-white" : "bg-surface-2 group-hover:bg-[#222222]",
                )}
              >
                <Icon name={item.icon} size={17} />
              </span>
              {t(item.label)}
            </Link>
            </div>
          );
        })}
      </nav>
      <div className="border-t border-border p-3">
        <LanguageToggle />
        <div className="flex items-center gap-3 rounded-xl p-2">
          <div className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-primary text-xs font-bold">
            {initials(user?.name)}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold">{user?.name}</p>
            <p className="truncate text-xs text-text-dim">{user?.staff_role ? t(STAFF_ROLE_LABEL[user.staff_role]) : (user?.company?.name ?? user?.email)}</p>
          </div>
          <button
            onClick={() => logout()}
            className="grid h-9 w-9 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-danger"
            aria-label={t("Log out")}
            title={t("Log out")}
          >
            <Icon name="logout" size={18} />
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-dvh w-full">
      <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 border-r border-border bg-surface/60 lg:block">{sidebar}</aside>

      {open && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-black/60 animate-fade-in" onClick={() => setOpen(false)} />
          <aside className="absolute inset-y-0 left-0 w-72 max-w-[85vw] border-r border-border bg-surface animate-pop-in">
            {sidebar}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-40 flex h-14 items-center gap-3 border-b border-border bg-bg/80 px-4 backdrop-blur-xl lg:hidden">
          <button
            onClick={() => setOpen(true)}
            className="grid h-9 w-9 place-items-center rounded-full hover:bg-surface-2"
            aria-label={t("Open menu")}
          >
            <Icon name="menu" />
          </button>
          <Logo size={20} />
          <span className="ml-auto rounded-full bg-surface-2 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-text-muted">
            {t(title)}
          </span>
        </header>
        <main className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{blocked ? <NoAccess /> : children}</main>
      </div>
    </div>
  );
}

function LanguageToggle() {
  const { lang, setLang } = useLang();
  return (
    <div role="radiogroup" aria-label="Language" className="mb-2 flex rounded-xl bg-surface-2 p-1">
      {LANGS.map((l) => (
        <button
          key={l.code}
          role="radio"
          aria-checked={l.code === lang}
          onClick={() => setLang(l.code)}
          className={cn(
            "flex-1 rounded-lg py-1.5 text-xs font-semibold transition-colors",
            l.code === lang ? "bg-primary text-white" : "text-text-muted hover:text-text",
          )}
        >
          {l.label}
        </button>
      ))}
    </div>
  );
}
