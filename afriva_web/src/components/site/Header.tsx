"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { useAuth } from "@/lib/auth";
import { LANGS, useLang, useT } from "@/lib/i18n";
import { cn, formatNumber, initials } from "@/lib/format";
import { buttonClass } from "../ui/Button";
import { Icon, type IconName } from "../ui/Icon";
import { Logo } from "../ui/Logo";

// Nyumbani · Vinjari · Vipendwa · VIP · App (search sits in the header; Profile is the avatar).
const NAV: { href: string; label: string; icon: IconName }[] = [
  { href: "/", label: "Home", icon: "home" },
  { href: "/browse", label: "Browse", icon: "grid" },
  { href: "/account?tab=list", label: "Favorites", icon: "bookmark" },
  { href: "/vip", label: "VIP", icon: "crown" },
  { href: "/app", label: "App", icon: "download" },
];

const FEEDBACK_HREF = "mailto:support@afriva.com?subject=Afriva%20feedback";

/** Close a popover on outside click / Escape. */
function useDismiss(open: boolean, close: () => void, ref: React.RefObject<HTMLElement | null>) {
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) close();
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && close();
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, close, ref]);
}

function SearchField({ onDone, className, autoFocus }: { onDone?: () => void; className?: string; autoFocus?: boolean }) {
  const t = useT();
  const router = useRouter();
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
      <Icon name="search" size={18} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" />
      <input
        type="search"
        autoFocus={autoFocus}
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t("Search")}
        aria-label={t("Search dramas")}
        className="h-11 w-full rounded-full border border-transparent bg-[#3A3A3A] pl-11 pr-4 text-[15px] text-white placeholder:text-[#9A9A9A] transition focus:border-white/30 focus:outline-none"
      />
    </form>
  );
}

function LanguageMenu({ className }: { className?: string }) {
  const { lang, setLang } = useLang();
  const t = useT();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useDismiss(open, () => setOpen(false), ref);
  const current = LANGS.find((l) => l.code === lang)!;
  return (
    <div ref={ref} className={cn("relative", className)}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={t("Language: {lang}", { lang: current.label })}
        className="flex items-center gap-1.5 py-2 text-[17px] font-normal text-white transition hover:text-primary xl:text-xl"
      >
        {current.label}
        <Icon name="chevron-down" size={16} />
      </button>
      {open && (
        <ul
          role="listbox"
          aria-label={t("Language")}
          className="absolute left-0 top-12 z-50 w-40 overflow-hidden rounded-xl border border-border bg-surface p-1 shadow-2xl animate-pop-in"
        >
          {LANGS.map((l) => (
            <li key={l.code}>
              <button
                role="option"
                aria-selected={l.code === lang}
                onClick={() => {
                  setLang(l.code);
                  setOpen(false);
                }}
                className="flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm text-text-muted transition hover:bg-surface-2 hover:text-text"
              >
                {l.label}
                {l.code === lang && <Icon name="check" size={15} className="text-primary" />}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function UserMenu() {
  const { user, logout } = useAuth();
  const t = useT();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const router = useRouter();
  useDismiss(open, () => setOpen(false), ref);

  if (!user) return null;
  const vip = !!user.active_subscription;

  const items: { href: string; label: string; icon: IconName }[] = [
    { href: "/account", label: "Profile", icon: "user" },
    { href: "/foryou", label: "For You", icon: "play" },
    { href: "/account?tab=list", label: "Favorites", icon: "bookmark" },
    { href: "/account?tab=history", label: "Watch history", icon: "history" },
    { href: "/account?tab=coins", label: "Coins", icon: "coin" },
    { href: "/account?tab=payments", label: "Transactions", icon: "wallet" },
    { href: "/vip", label: vip ? "VIP & coins" : "Go VIP", icon: "crown" },
    { href: "/account?tab=creator", label: "Submit your work", icon: "upload" },
  ];
  if (user.role === "super_admin") items.unshift({ href: "/admin", label: "Admin portal", icon: "shield" });
  if (user.role === "company") items.unshift({ href: "/studio", label: "Creator Studio", icon: "film" });

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t("Account menu")}
        className="flex items-center rounded-full transition hover:opacity-90"
      >
        <span
          className={cn(
            "grid h-11 w-11 place-items-center rounded-full bg-[#5A5A5A] text-sm font-bold text-white",
            vip && "ring-2 ring-primary ring-offset-2 ring-offset-bg",
          )}
        >
          {initials(user.name)}
        </span>
      </button>
      {open && (
        <div role="menu" className="absolute right-0 top-14 z-50 w-64 overflow-hidden rounded-2xl border border-border bg-surface shadow-2xl animate-pop-in">
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
                <Icon name={it.icon} size={17} /> {t(it.label)}
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
              <Icon name="logout" size={17} /> {t("Log out")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/** Grey silhouette used when signed out. */
function DefaultAvatar() {
  return (
    <svg viewBox="0 0 44 44" width="44" height="44" aria-hidden="true">
      <circle cx="22" cy="17" r="7.5" fill="currentColor" />
      <path d="M8 40c1.6-8 7.4-12 14-12s12.4 4 14 12" fill="currentColor" />
    </svg>
  );
}

function AuthSlot() {
  const { user, loading } = useAuth();
  const t = useT();
  if (loading) return <div className="skeleton h-11 w-11 rounded-full" />;
  if (user) return <UserMenu />;
  return (
    <Link href="/login" aria-label={t("Log in")} title={t("Log in")} className="grid h-11 w-11 place-items-center overflow-hidden rounded-full bg-[#5A5A5A] text-[#BDBDBD] transition hover:text-white">
      <DefaultAvatar />
    </Link>
  );
}

function HeaderInner() {
  const pathname = usePathname();
  const { user } = useAuth();
  const t = useT();
  const [menuOpen, setMenuOpen] = useState(false);

  const isActive = (href: string) => {
    const path = href.split("?")[0]!;
    if (href.includes("?")) return false;
    return path === "/" ? pathname === "/" : pathname.startsWith(path);
  };

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
      <header className="chrome-dark sticky top-0 z-50 bg-bg">
        <div className="site-container flex h-16 items-center gap-3 lg:h-[88px] lg:gap-10 xl:gap-14 min-[1800px]:gap-[120px]">
          <button
            className="-ml-2 grid h-10 w-10 place-items-center rounded-full text-white hover:bg-white/10 lg:hidden"
            aria-label={t("Open menu")}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(true)}
          >
            <Icon name="menu" size={22} />
          </button>
          <Link href="/" aria-label={t("Afriva home")} className="shrink-0">
            <span className="hidden lg:block">
              <Logo size={34} />
            </span>
            <span className="lg:hidden">
              <Logo size={26} />
            </span>
          </Link>

          <nav className="hidden items-center gap-10 lg:flex xl:gap-14 min-[1800px]:gap-[120px]" aria-label={t("Main")}>
            {NAV.map((n) => (
              <Link
                key={n.href}
                href={n.href}
                aria-current={isActive(n.href) ? "page" : undefined}
                className={cn(
                  "py-2 text-[17px] font-normal transition-colors duration-150 xl:text-xl",
                  isActive(n.href) ? "text-primary" : "text-white hover:text-primary",
                )}
              >
                {t(n.label)}
              </Link>
            ))}
            <LanguageMenu />
          </nav>

          <div className="ml-auto flex items-center gap-3 xl:gap-4">
            <SearchField className="hidden w-[260px] lg:block xl:w-[320px] min-[1600px]:w-[390px]" />
            <Link
              href="/search"
              className="grid h-10 w-10 place-items-center rounded-full bg-[#3A3A3A] text-white lg:hidden"
              aria-label={t("Search")}
            >
              <Icon name="search" size={18} />
            </Link>
            <a
              href={FEEDBACK_HREF}
              className="hidden h-11 w-11 place-items-center rounded-full bg-[#3A3A3A] text-white transition hover:bg-[#474747] sm:grid"
              aria-label={t("Help & feedback")}
              title={t("Help & feedback")}
            >
              <Icon name="headset" size={20} />
            </a>
            <AuthSlot />
          </div>
        </div>
      </header>

      {menuOpen && (
        <div className="chrome-dark fixed inset-0 z-[60] lg:hidden" role="dialog" aria-modal="true" aria-label={t("Menu")}>
          <div className="absolute inset-0 bg-black/70 animate-fade-in" onClick={() => setMenuOpen(false)} />
          <div className="absolute inset-y-0 left-0 flex w-[85vw] max-w-xs flex-col border-r border-border bg-bg pb-safe animate-pop-in">
            <div className="flex h-16 items-center justify-between px-4">
              <Logo size={22} />
              <button onClick={() => setMenuOpen(false)} className="grid h-10 w-10 place-items-center rounded-full hover:bg-surface-2" aria-label={t("Close menu")}>
                <Icon name="x" />
              </button>
            </div>
            <div className="px-4 pb-3">
              <SearchField onDone={() => setMenuOpen(false)} />
            </div>
            <nav className="flex-1 overflow-y-auto px-2" aria-label={t("Mobile")}>
              {[
                ...NAV,
                { href: "/search", label: "Search", icon: "search" as IconName },
                { href: "/foryou", label: "For You", icon: "play" as IconName },
                ...(user ? [{ href: "/account", label: "Profile", icon: "user" as IconName }] : []),
                { href: "/account?tab=creator", label: "Submit your work", icon: "upload" as IconName },
              ].map((n) => (
                <Link
                  key={n.href}
                  href={n.href}
                  onClick={() => setMenuOpen(false)}
                  className={cn(
                    "flex items-center gap-3 rounded-xl px-3 py-3 text-[15px] font-semibold transition-colors",
                    isActive(n.href) ? "bg-white/5 text-text" : "text-text-muted hover:bg-surface-2 hover:text-text",
                  )}
                >
                  <Icon name={n.icon} size={19} className={isActive(n.href) ? "text-primary" : undefined} />
                  {t(n.label)}
                </Link>
              ))}
              <a
                href={FEEDBACK_HREF}
                className="flex items-center gap-3 rounded-xl px-3 py-3 text-[15px] font-semibold text-text-muted hover:bg-surface-2 hover:text-text"
              >
                <Icon name="headset" size={19} /> {t("Help & feedback")}
              </a>
            </nav>
            <div className="flex items-center justify-between gap-3 border-t border-border p-4">
              <LanguageMenu />
              {!user && (
                <Link href="/login" onClick={() => setMenuOpen(false)} className={buttonClass("primary", "sm")}>
                  {t("Log in")}
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
    <header className="chrome-dark sticky top-0 z-50 bg-bg">
      <div className="site-container flex h-16 items-center gap-4 lg:h-[88px]">
        <span className="w-8 lg:hidden" />
        <span className="hidden lg:block">
          <Logo size={34} />
        </span>
        <span className="lg:hidden">
          <Logo size={26} />
        </span>
        <div className="skeleton ml-auto h-11 w-11 rounded-full" />
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
