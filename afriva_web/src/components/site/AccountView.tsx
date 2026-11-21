"use client";

import Image from "next/image";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useRouter } from "@/lib/navigation";
import { useEffect, useRef, useState } from "react";
import { useLocale, useT } from "@/i18n/client";
import { fmt, plural } from "@/i18n/format";
import { useApi, useList } from "@/lib/hooks";
import { isVip, useAuth } from "@/lib/auth";
import { cn, formatDate, formatDuration, formatMoney, formatNumber, initials } from "@/lib/format";
import { NETWORKS, formatPhone, networkName } from "@/lib/payments";
import type { Drama, HistoryItem, Payment, Subscription } from "@/lib/types";
import { RoleGuard } from "../RoleGuard";
import { Button } from "../ui/Button";
import { ApiDownState, EmptyState, StatusPill } from "../ui/Feedback";
import { Icon, type IconName } from "../ui/Icon";
import { PosterCard, PosterCardSkeleton, gridClass } from "./PosterCard";
import { CardBrandMark, NetworkMark } from "./payments/PayMarks";
import { PaymentMethodsManager } from "./payments/PaymentMethodsManager";

const TABS: { key: "overview" | "list" | "history" | "payments"; icon: IconName }[] = [
  { key: "overview", icon: "user" },
  { key: "list", icon: "bookmark" },
  { key: "history", icon: "history" },
  { key: "payments", icon: "wallet" },
];

export function AccountView() {
  return (
    <RoleGuard>
      <AccountInner />
    </RoleGuard>
  );
}

function AccountInner() {
  const { user, logout } = useAuth();
  const params = useSearchParams();
  const router = useRouter();
  const t = useT().user.account;
  const creatorT = useT().creator;
  const tab = TABS.some((x) => x.key === params.get("tab")) ? params.get("tab")! : "overview";
  const tabsRef = useRef<HTMLDivElement>(null);
  // Keep the active tab visible in the scrolling tab bar on phones (e.g. deep links to Payments).
  useEffect(() => {
    const bar = tabsRef.current;
    const active = bar?.querySelector<HTMLElement>("[aria-selected=true]");
    if (bar && active) bar.scrollLeft = Math.max(0, active.offsetLeft - (bar.clientWidth - active.offsetWidth) / 2);
  }, [tab, user]);
  if (!user) return null;
  const vip = isVip(user);

  return (
    <div className="mx-auto max-w-[1200px] px-4 pt-8 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-5 rounded-[28px] bg-surface p-5 sm:flex-row sm:items-center sm:p-7">
        <div
          className={cn(
            "grid h-16 w-16 shrink-0 place-items-center rounded-full bg-text/10 text-xl font-bold sm:h-20 sm:w-20 sm:text-2xl",
            vip && "ring-2 ring-primary",
          )}
        >
          {initials(user.name)}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="truncate text-xl font-extrabold sm:text-2xl">{user.name}</h1>
            {vip && (
              <span className="flex items-center gap-1 rounded-full bg-primary/15 px-2.5 py-0.5 text-xs font-bold text-primary">
                <Icon name="crown" size={13} /> VIP
              </span>
            )}
          </div>
          <p className="truncate text-sm text-text-muted">{[user.email, user.phone].filter(Boolean).join(" · ")}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button href="/vip" variant="gold" size="sm">
            <Icon name="coin" size={15} /> {t.topUp}
          </Button>
          {user.role === "viewer" && (
            <Button href="/apply" variant="outline" size="sm">
              <Icon name="film" size={15} /> {creatorT.requestToPost}
            </Button>
          )}
          <Button
            variant="outline"
            size="sm"
            onClick={async () => {
              await logout();
              router.push("/");
            }}
          >
            <Icon name="logout" size={15} /> {t.logOut}
          </Button>
        </div>
      </div>

      <div ref={tabsRef} className="scrollbar-none sticky top-(--header-h) z-20 -mx-4 mt-6 flex gap-1 overflow-x-auto bg-bg/72 px-4 backdrop-blur-xl sm:mx-0 sm:px-0" role="tablist">
        {TABS.map((x) => (
          <Link
            key={x.key}
            role="tab"
            aria-selected={tab === x.key}
            href={x.key === "overview" ? "/account" : `/account?tab=${x.key}`}
            scroll={false}
            className={cn(
              "relative flex shrink-0 items-center gap-2 px-4 py-3 text-sm font-bold transition-colors",
              tab === x.key ? "text-text" : "text-text-dim hover:text-text-muted",
            )}
          >
            <Icon name={x.icon} size={16} /> {t.tabs[x.key]}
            {tab === x.key && <span className="absolute inset-x-3 bottom-0 h-0.5 rounded-full bg-primary" />}
          </Link>
        ))}
      </div>

      <div className="mt-6">
        {tab === "overview" && <Overview />}
        {tab === "list" && <MyList />}
        {tab === "history" && <History />}
        {tab === "payments" && <Payments />}
      </div>
    </div>
  );
}

function Overview() {
  const { user } = useAuth();
  const t = useT().user.account;
  const locale = useLocale();
  const sub = useApi<Subscription | null>("/me/subscription");
  const meta = (sub.meta ?? {}) as Record<string, unknown>;
  const active = sub.data ?? user?.active_subscription ?? null;
  const coins = typeof meta.coins === "number" ? meta.coins : user?.coins ?? 0;
  const episodesRemaining = Number(meta.episodes_remaining ?? active?.episodes_remaining ?? 0);

  return (
    <div className="grid gap-4 md:grid-cols-3">
      <div className="rounded-2xl bg-surface p-5">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t.coinBalance}</p>
        <p className="mt-2 flex items-center gap-2 text-3xl font-extrabold text-primary">
          <Icon name="coin" size={28} /> {formatNumber(coins)}
        </p>
        <p className="mt-1 text-xs text-text-muted">{t.coinHint}</p>
        <Link href="/vip#coins" className="mt-4 inline-block text-sm font-semibold text-primary hover:underline">
          {t.buyCoins}
        </Link>
      </div>
      <div className="rounded-2xl bg-surface p-5 md:col-span-2">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t.subscription}</p>
        {sub.loading ? (
          <div className="skeleton mt-3 h-14 rounded-xl" />
        ) : active && active.type !== "episodes" ? (
          <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="flex items-center gap-2 text-xl font-extrabold">
                <Icon name="crown" className="text-primary" /> {active.plan?.name ?? fmt(t.vipFallback, { type: active.type })}
              </p>
              <p className="mt-1 text-sm text-text-muted">
                {fmt(t.activeSince, { date: formatDate(active.starts_at, false, locale) })} ·{" "}
                {active.ends_at ? fmt(t.renews, { date: formatDate(active.ends_at, false, locale) }) : t.noExpiry}
              </p>
            </div>
            <StatusPill status={active.status} />
          </div>
        ) : (
          <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-xl font-extrabold">{t.freePlan}</p>
              <p className="mt-1 text-sm text-text-muted">{t.freePlanHint}</p>
            </div>
            <Button href="/vip" size="sm">
              <Icon name="crown" size={15} /> {t.goVip}
            </Button>
          </div>
        )}
        {episodesRemaining > 0 && (
          <p className="mt-4 flex items-center gap-2 rounded-xl bg-surface-2 p-3 text-sm">
            <Icon name="layers" size={17} className="text-primary" /> {plural(episodesRemaining, t.packLeft)}
          </p>
        )}
      </div>
      <div className="rounded-2xl bg-surface p-5 md:col-span-3">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t.profile}</p>
        <dl className="mt-3 grid gap-4 text-sm sm:grid-cols-3">
          <div>
            <dt className="text-text-dim">{t.name}</dt>
            <dd className="mt-0.5 font-semibold">{user?.name}</dd>
          </div>
          <div>
            <dt className="text-text-dim">{t.email}</dt>
            <dd className="mt-0.5 font-semibold break-all">{user?.email ?? "-"}</dd>
          </div>
          <div>
            <dt className="text-text-dim">{t.phone}</dt>
            <dd className="mt-0.5 font-semibold">{user?.phone ?? "-"}</dd>
          </div>
          <div>
            <dt className="text-text-dim">{t.memberSince}</dt>
            <dd className="mt-0.5 font-semibold">{formatDate(user?.created_at, false, locale)}</dd>
          </div>
        </dl>
      </div>
    </div>
  );
}

function MyList() {
  const t = useT().user.account;
  const list = useList<Drama>("/me/favorites", { per_page: 60 });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t.retry}</Button>} />;
  if (list.loading)
    return (
      <div className={gridClass}>
        {Array.from({ length: 7 }).map((_, i) => (
          <PosterCardSkeleton key={i} />
        ))}
      </div>
    );
  if (!list.items.length)
    return (
      <EmptyState
        icon="bookmark"
        title={t.listEmpty}
        description={t.listEmptyHint}
        action={<Button href="/browse">{t.browse}</Button>}
      />
    );
  return (
    <div className={gridClass}>
      {list.items.map((d) => (
        <PosterCard key={d.id} drama={d} />
      ))}
    </div>
  );
}

function History() {
  const [page, setPage] = useState(1);
  const t = useT().user.account;
  const locale = useLocale();
  const list = useList<HistoryItem>("/me/history", { page });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t.retry}</Button>} />;
  if (list.loading)
    return (
      <div className="grid gap-3 sm:grid-cols-2">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="skeleton h-28 rounded-2xl" />
        ))}
      </div>
    );
  if (!list.items.length)
    return <EmptyState icon="history" title={t.historyEmpty} description={t.historyEmptyHint} action={<Button href="/">{t.startWatching}</Button>} />;
  return (
    <>
      <div className="grid gap-3 sm:grid-cols-2">
        {list.items.map((h) => {
          const epNo = h.episode?.number ?? 1;
          const dur = (h.episode as { duration_seconds?: number } | null | undefined)?.duration_seconds ?? 0;
          const pct = dur ? Math.min(100, Math.round((h.progress_seconds / dur) * 100)) : 0;
          return (
            <Link
              key={h.id ?? h.drama.id}
              href={`/drama/${h.drama.slug}/ep/${epNo}`}
              className="group flex gap-4 rounded-2xl bg-surface p-3 transition hover:bg-surface-2"
            >
              <div className="relative aspect-[9/16] w-[72px] shrink-0 overflow-hidden rounded-lg bg-surface-2">
                {h.drama.poster_url && <Image src={h.drama.poster_url} alt="" fill sizes="72px" className="object-cover" />}
                <div className="absolute inset-0 grid place-items-center bg-black/30 opacity-0 transition group-hover:opacity-100">
                  <Icon name="play" size={20} />
                </div>
              </div>
              <div className="min-w-0 flex-1 py-1">
                <h3 className="line-clamp-1 font-bold group-hover:text-primary">{h.drama.title}</h3>
                <p className="mt-1 text-xs text-text-muted">
                  {fmt(t.continueEp, { n: epNo, total: h.drama.total_episodes })}
                  {h.progress_seconds ? fmt(t.atTime, { time: formatDuration(h.progress_seconds) }) : ""}
                </p>
                <div className="mt-3 h-1 overflow-hidden rounded-full bg-surface-2">
                  <div className="h-full rounded-full bg-primary" style={{ width: `${Math.max(pct, 4)}%` }} />
                </div>
                <p className="mt-2 text-[11px] text-text-dim">{formatDate(h.updated_at, false, locale)}</p>
              </div>
            </Link>
          );
        })}
      </div>
      {list.meta && list.meta.last_page > 1 && (
        <div className="mt-6 flex justify-center gap-2">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            {t.previous}
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            {t.next}
          </Button>
        </div>
      )}
    </>
  );
}

function MethodBadge({ code }: { code: string | null }) {
  if (code === "visa" || code === "mastercard")
    return (
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-surface-2">
        <CardBrandMark brand={code} className="h-5 w-[30px]" />
      </span>
    );
  if (code && code in NETWORKS) return <NetworkMark code={code} />;
  return (
    <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-surface-2 text-text-dim">
      <Icon name="wallet" size={17} />
    </span>
  );
}

function methodLabel(p: Payment) {
  const m = p.payment_method;
  if (m && typeof m === "object") return m.name;
  return networkName(p.payment_method_code ?? (typeof m === "string" ? m : ""));
}

function Payments() {
  const tp = useT().user.pay;
  return (
    <div className="space-y-10">
      <PaymentMethodsManager />
      <section>
        <h2 className="mb-4 text-lg font-extrabold tracking-tight">{tp.historyTitle}</h2>
        <PaymentHistory />
      </section>
    </div>
  );
}

function PaymentHistory() {
  const [page, setPage] = useState(1);
  const t = useT().user.account;
  const locale = useLocale();
  const list = useList<Payment>("/me/payments", { page });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t.retry}</Button>} />;
  if (list.loading) return <div className="skeleton h-64 rounded-2xl" />;
  if (!list.items.length)
    return <EmptyState icon="wallet" title={t.paymentsEmpty} description={t.paymentsEmptyHint} action={<Button href="/vip">{t.seePlans}</Button>} />;
  return (
    <>
      <div className="overflow-hidden rounded-2xl bg-surface">
        <ul className="divide-y divide-border/70">
          {list.items.map((p) => (
            <li key={p.id} className="flex items-center gap-3 px-4 py-3.5 sm:gap-4">
              <MethodBadge code={p.payment_method_code ?? (typeof p.payment_method === "string" ? p.payment_method : null)} />
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold">{p.plan?.name ?? t.purchase}</p>
                <p className="truncate text-xs text-text-dim">
                  <span>{methodLabel(p)}</span>
                  {p.phone ? <span className="tabular-nums"> {formatPhone(p.phone, true)}</span> : null} · <span className="font-mono">{p.reference}</span> · {formatDate(p.paid_at ?? p.created_at, true, locale)}
                </p>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1 sm:flex-row sm:items-center sm:gap-4">
                <p className="text-sm font-bold tabular-nums sm:text-base">{formatMoney(p.amount, p.currency)}</p>
                <StatusPill status={p.status} />
              </div>
            </li>
          ))}
        </ul>
      </div>
      {list.meta && list.meta.last_page > 1 && (
        <div className="mt-6 flex justify-center gap-2">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            {t.previous}
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            {t.next}
          </Button>
        </div>
      )}
    </>
  );
}
