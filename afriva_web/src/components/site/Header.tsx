"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { useT } from "@/i18n/client";
import { stripLocale } from "@/i18n/config";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { isVip, useAuth } from "@/lib/auth";
import { cn, formatNumber, initials } from "@/lib/format";
import { LanguageMenu, useDismiss } from "../LanguageMenu";
import { ThemeToggle } from "../ThemeToggle";
import { buttonClass } from "../ui/Button";
import { Icon, type IconName } from "../ui/Icon";
import { Logo } from "../ui/Logo";
import { roleUrl } from "@/lib/portals";

type NavLink = { href: string; label: string; icon: IconName };

function mainNav(t: Dictionary["common"]["nav"]): NavLink[] {
  return [
    { href: "/", label: t.home, icon: "home" },
    { href: "/browse", label: t.browse, icon: "grid" },
    { href: "/rankings", label: t.rankings, icon: "trophy" },
    { href: "/app", label: t.app, icon: "download" },
  ];
}

const FEEDBACK_HREF = "mailto:support@afriva.co.tz?subject=Afriva%20feedback";

function SearchField({ onDone, className, autoFocus }: { onDone?: () => void; className?: string; autoFocus?: boolean }) {
  const router = useRouter();
  const t = useT().common.header;
  const [q, setQ] = useState("");
  return (
    <form
      role="search"
      className={cn("relative", className)}
      onSubmit={(e) => {
        e.preventDefault();
        const term = q.trim();
        router.push(term ? `/search?q=${encodeURIComponent(term)}` : "/search");
        onDone?.();
      }}
    >
      <Icon name="search" size={17} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" />
      <input
        type="search"
        autoFocus={autoFocus}
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t.search}
        aria-label={t.searchDramas}
        className="h-10 w-full rounded-full bg-text/10 pl-11 pr-4 text-sm text-text placeholder:text-text-dim transition focus:bg-text/15 focus:outline-none focus:ring-2 focus:ring-text/20"
      />
    </form>
  );
}

function UserMenu() {
  const { user, logout } = useAuth();
  const t = useT().common.header;
  const nav = useT().common.nav;
  const creatorT = useT().creator as Dictionary["creator"] | undefined;
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const router = useRouter();
  useDismiss(open, () => setOpen(false), ref);

  if (!user) return null;
  const vip = isVip(user);

  const items: { href: string; label: string; icon: IconName }[] = [
    { href: "/account", label: t.myAccount, icon: "user" },
    { href: "/foryou", label: nav.forYou, icon: "play" },
    { href: "/account?tab=list", label: t.myList, icon: "bookmark" },
    { href: "/account?tab=history", label: t.history, icon: "history" },
    { href: "/account?tab=payments", label: t.payments, icon: "wallet" },
    { href: "/vip", label: vip ? t.vipCoins : t.goVip, icon: "crown" },
  ];
  if (user.role === "viewer" && creatorT) items.push({ href: "/apply", label: creatorT.requestToPost, icon: "film" });
  if (user.role === "super_admin") items.unshift({ href: roleUrl("super_admin", "/admin"), label: t.adminPortal, icon: "shield" });
  if (user.role === "company") items.unshift({ href: roleUrl("company", "/studio"), label: t.studioPortal, icon: "film" });

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t.accountMenu}
        className="flex items-center rounded-full transition hover:opacity-90"
      >
        <span
          className={cn(
            "grid size-10 place-items-center rounded-full bg-text/15 text-[13px] font-bold text-text",
            vip && "ring-2 ring-primary ring-offset-2 ring-offset-bg",
          )}
        >
          {initials(user.name)}
        </span>
      </button>
      {open && (
        <div role="menu" className="absolute right-0 top-12 z-50 w-64 overflow-hidden rounded-2xl bg-surface shadow-2xl ring-1 ring-text/10 animate-pop-in">
          <div className="border-b border-border p-4">
            <p className="truncate font-bold">{user.name}</p>
            <p className="truncate text-xs text-text-dim">{user.email ?? user.phone}</p>
            <div className="mt-3 flex items-center gap-2 text-xs">
              <span className="flex items-center gap-1 rounded-full bg-surface-2 px-2 py-0.5 font-bold text-text">
                <Icon name="coin" size={13} className="text-primary" /> {formatNumber(user.coins)}
              </span>
              {vip && (
                <span className="flex items-center gap-1 rounded-full bg-primary px-2 py-0.5 font-bold text-white">
                  <Icon name="crown" size={13} /> VIP
                </span>
              )}
            </div>
          </div>
          <div className="p-1.5">
            {items.map((it) => (
              <Link
                key={it.href}
                href={it.href}
                role="menuitem"
                onClick={() => setOpen(false)}
                className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-text-muted transition hover:bg-surface-2 hover:text-text"
              >
                <Icon name={it.icon} size={17} /> {it.label}
              </Link>
            ))}
            <button
              role="menuitem"
              onClick={async () => {
                setOpen(false);
                await logout();
                router.push("/");
              }}
              className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-text-muted transition hover:bg-surface-2 hover:text-primary"
            >
              <Icon name="logout" size={17} /> {t.logOut}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function AuthSlot() {
  const { user, loading } = useAuth();
  const t = useT().common.header;
  if (loading) return <div className="skeleton hidden size-10 rounded-full lg:block" />;
  if (user) return <UserMenu />;
  return (
    <span className="hidden lg:block">
      <Link href="/login" className={buttonClass("gold", "md")}>
        {t.logIn}
      </Link>
    </span>
  );
}

function HeaderInner() {
  const pathname = stripLocale(usePathname());
  const [scrolled, setScrolled] = useState(false);
  const { user } = useAuth();
  const { header: t, nav } = useT().common;
  const NAV = mainNav(nav);
  const [menuOpen, setMenuOpen] = useState(false);

  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname.startsWith(href));

  // Clear over the artwork at the top of a page, frosted once content scrolls beneath it.
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const esc = (e: KeyboardEvent) => e.key === "Escape" && setMenuOpen(false);
    document.addEventListener("keydown", esc);
    return () => {
      document.body.style.overflow = prev;
      document.removeEventListener("keydown", esc);
    };
  }, [menuOpen]);

  return (
    <>
      <header
        className={cn(
          "sticky top-0 z-50 text-text transition-[background-color,backdrop-filter] duration-300",
          scrolled ? "bg-bg/72 backdrop-blur-2xl backdrop-saturate-150" : "bg-transparent",
        )}
      >
        <div className="site-container flex h-(--header-h) items-center gap-3 lg:gap-8 xl:gap-10">
          <button
            className="-ml-2 grid size-10 place-items-center rounded-full text-text hover:bg-text/10 lg:hidden"
            aria-label={t.openMenu}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(true)}
          >
            <Icon name="menu" size={22} />
          </button>
          <Link href="/" aria-label={t.homeLink} className="shrink-0">
            <span className="hidden lg:block">
              <Logo size={28} />
            </span>
            <span className="lg:hidden">
              <Logo size={24} />
            </span>
          </Link>

          <nav className="hidden items-center gap-6 lg:flex xl:gap-8" aria-label={nav.main}>
            {NAV.map((n) => (
              <Link
                key={n.href}
                href={n.href}
                aria-current={isActive(n.href) ? "page" : undefined}
                className={cn(
                  "py-2 text-[15px] font-medium transition-colors duration-150",
                  isActive(n.href) ? "text-text" : "text-text-muted hover:text-text",
                )}
              >
                {n.label}
              </Link>
            ))}
            <Link
              href="/foryou"
              aria-current={isActive("/foryou") ? "page" : undefined}
              className={cn("hidden py-2 text-[15px] font-medium transition-colors xl:block", isActive("/foryou") ? "text-text" : "text-text-muted hover:text-text")}
            >
              {nav.forYou}
            </Link>
            <LanguageMenu buttonClassName="py-2 text-[15px] font-medium text-text-muted hover:text-text" />
          </nav>

          <div className="ml-auto flex items-center gap-2 xl:gap-2.5">
            <SearchField className="hidden w-[190px] lg:block xl:w-[280px] min-[1600px]:w-[340px]" />
            <Link
              href="/search"
              className="grid size-10 place-items-center rounded-full text-text hover:bg-text/10 lg:hidden"
              aria-label={t.search}
            >
              <Icon name="search" size={18} />
            </Link>
            <ThemeToggle className="hidden size-10 items-center justify-center rounded-full text-text-muted hover:bg-text/10 hover:text-text lg:flex" />
            <a
              href={FEEDBACK_HREF}
              className="hidden size-10 place-items-center rounded-full text-text-muted transition hover:bg-text/10 hover:text-text lg:grid"
              aria-label={t.help}
              title={t.help}
            >
              <Icon name="headset" size={19} />
            </a>
            <AuthSlot />
          </div>
        </div>
      </header>

      {menuOpen && (
        <div className="fixed inset-0 z-[60] text-text lg:hidden" role="dialog" aria-modal="true" aria-label={t.menu}>
          <div className="absolute inset-0 bg-black/70 animate-fade-in" onClick={() => setMenuOpen(false)} />
          <div className="absolute inset-y-0 left-0 flex w-[85vw] max-w-xs flex-col bg-bg pb-safe animate-pop-in">
            <div className="flex h-16 items-center justify-between px-4">
              <Logo size={22} />
              <button onClick={() => setMenuOpen(false)} className="grid h-10 w-10 place-items-center rounded-full hover:bg-surface-2" aria-label={t.closeMenu}>
                <Icon name="x" />
              </button>
            </div>
            <div className="px-4 pb-3">
              <SearchField onDone={() => setMenuOpen(false)} />
            </div>
            <nav className="flex-1 overflow-y-auto px-2" aria-label={nav.mobile}>
              {[...NAV, { href: "/foryou", label: nav.forYou, icon: "play" as IconName }, { href: "/vip", label: nav.vip, icon: "crown" as IconName }, ...(user ? [{ href: "/account", label: t.myAccount, icon: "user" as IconName }] : [])].map((n) => (
                <Link
                  key={n.href}
                  href={n.href}
                  onClick={() => setMenuOpen(false)}
                  className={cn(
                    "flex items-center gap-3 rounded-xl px-3 py-3 text-[15px] font-semibold transition-colors",
                    isActive(n.href) ? "bg-text/5 text-text" : "text-text-muted hover:bg-surface-2 hover:text-text",
                  )}
                >
                  <Icon name={n.icon} size={19} className={isActive(n.href) ? "text-primary" : undefined} />
                  {n.label}
                </Link>
              ))}
              <a
                href={FEEDBACK_HREF}
                className="flex items-center gap-3 rounded-xl px-3 py-3 text-[15px] font-semibold text-text-muted hover:bg-surface-2 hover:text-text"
              >
                <Icon name="headset" size={19} /> {t.help}
              </a>
            </nav>
            <div className="flex items-center justify-between gap-3 border-t border-border p-4">
              <div className="flex items-center gap-4">
                <LanguageMenu up buttonClassName="text-sm font-semibold text-text-muted hover:text-text" />
                <ThemeToggle withLabel className="text-sm font-semibold text-text-muted hover:text-text" />
              </div>
              {!user && (
                <Link href="/login" onClick={() => setMenuOpen(false)} className={buttonClass("primary", "sm")}>
                  {t.logIn}
                </Link>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
}

/** Static shell rendered while route data (pathname) streams in. */
function HeaderFallback() {
  return (
    <header className="sticky top-0 z-50">
      <div className="site-container flex h-(--header-h) items-center gap-4">
        <span className="w-8 lg:hidden" />
        <span className="hidden lg:block">
          <Logo size={28} />
        </span>
        <span className="lg:hidden">
          <Logo size={24} />
        </span>
        <div className="skeleton ml-auto hidden size-10 rounded-full lg:block" />
      </div>
    </header>
  );
}

export function Header() {
  return (
    <Suspense fallback={<HeaderFallback />}>
      <HeaderInner />
    </Suspense>
  );
}
