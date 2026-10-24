"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { useApi, useList } from "@/lib/hooks";
import { useAuth } from "@/lib/auth";
import { cn, formatDate, formatDuration, formatMoney, formatNumber, initials } from "@/lib/format";
import type { Drama, HistoryItem, Payment, Subscription } from "@/lib/types";
import { RoleGuard } from "../RoleGuard";
import { Button } from "../ui/Button";
import { ApiDownState, EmptyState, StatusPill } from "../ui/Feedback";
import { Icon, type IconName } from "../ui/Icon";
import { PosterCard, PosterCardSkeleton, gridClass } from "./PosterCard";

const TABS: { key: string; label: string; icon: IconName }[] = [
  { key: "overview", label: "Overview", icon: "user" },
  { key: "list", label: "My List", icon: "bookmark" },
  { key: "history", label: "History", icon: "history" },
  { key: "payments", label: "Payments", icon: "wallet" },
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
  const tab = TABS.some((t) => t.key === params.get("tab")) ? params.get("tab")! : "overview";
  if (!user) return null;
  const vip = !!user.active_subscription;

  return (
    <div className="mx-auto max-w-[1200px] px-4 pt-8 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-5 rounded-3xl border border-border bg-gradient-to-br from-surface to-surface/40 p-5 sm:flex-row sm:items-center sm:p-7">
        <div
          className={cn(
            "grid h-16 w-16 shrink-0 place-items-center rounded-full bg-primary text-xl font-extrabold sm:h-20 sm:w-20 sm:text-2xl",
            vip && "ring-[3px] ring-primary ring-offset-4 ring-offset-surface",
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
            <Icon name="coin" size={15} /> Top up
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={async () => {
              await logout();
              router.push("/");
            }}
          >
            <Icon name="logout" size={15} /> Log out
          </Button>
        </div>
      </div>

      <div className="scrollbar-none sticky top-16 lg:top-[88px] z-20 -mx-4 mt-6 flex gap-1 overflow-x-auto border-b border-border bg-bg/85 px-4 backdrop-blur-xl sm:mx-0 sm:px-0" role="tablist">
        {TABS.map((t) => (
          <Link
            key={t.key}
            role="tab"
            aria-selected={tab === t.key}
            href={t.key === "overview" ? "/account" : `/account?tab=${t.key}`}
            scroll={false}
            className={cn(
              "relative flex shrink-0 items-center gap-2 px-4 py-3 text-sm font-bold transition-colors",
              tab === t.key ? "text-text" : "text-text-dim hover:text-text-muted",
            )}
          >
            <Icon name={t.icon} size={16} /> {t.label}
            {tab === t.key && <span className="absolute inset-x-3 bottom-0 h-0.5 rounded-full bg-primary" />}
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
  const sub = useApi<Subscription | null>("/me/subscription");
  const meta = (sub.meta ?? {}) as Record<string, unknown>;
  const active = sub.data ?? user?.active_subscription ?? null;
  const coins = typeof meta.coins === "number" ? meta.coins : user?.coins ?? 0;
  const episodesRemaining = Number(meta.episodes_remaining ?? active?.episodes_remaining ?? 0);

  return (
    <div className="grid gap-4 md:grid-cols-3">
      <div className="rounded-2xl border border-border bg-surface p-5">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">Coin balance</p>
        <p className="mt-2 flex items-center gap-2 text-3xl font-extrabold text-primary">
          <Icon name="coin" size={28} /> {formatNumber(coins)}
        </p>
        <p className="mt-1 text-xs text-text-muted">Use coins to unlock single episodes.</p>
        <Link href="/vip#coins" className="mt-4 inline-block text-sm font-semibold text-primary hover:underline">
          Buy coins →
        </Link>
      </div>
      <div className="rounded-2xl border border-border bg-surface p-5 md:col-span-2">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">Subscription</p>
        {sub.loading ? (
          <div className="skeleton mt-3 h-14 rounded-xl" />
        ) : active && active.type !== "episodes" ? (
          <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="flex items-center gap-2 text-xl font-extrabold">
                <Icon name="crown" className="text-primary" /> {active.plan?.name ?? `${active.type} VIP`}
              </p>
              <p className="mt-1 text-sm text-text-muted">
                Active since {formatDate(active.starts_at)} · {active.ends_at ? `renews manually on ${formatDate(active.ends_at)}` : "no expiry"}
              </p>
            </div>
            <StatusPill status={active.status} />
          </div>
        ) : (
          <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-xl font-extrabold">Free plan</p>
              <p className="mt-1 text-sm text-text-muted">Unlock every episode with VIP from 3,000 TZS/week.</p>
            </div>
            <Button href="/vip" size="sm">
              <Icon name="crown" size={15} /> Go VIP
            </Button>
          </div>
        )}
        {episodesRemaining > 0 && (
          <p className="mt-4 flex items-center gap-2 rounded-xl bg-surface-2 p-3 text-sm">
            <Icon name="layers" size={17} className="text-primary" /> {episodesRemaining} episode unlocks left in your pack
          </p>
        )}
      </div>
      <div className="rounded-2xl border border-border bg-surface p-5 md:col-span-3">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">Profile</p>
        <dl className="mt-3 grid gap-4 text-sm sm:grid-cols-3">
          <div>
            <dt className="text-text-dim">Name</dt>
            <dd className="mt-0.5 font-semibold">{user?.name}</dd>
          </div>
          <div>
            <dt className="text-text-dim">Email</dt>
            <dd className="mt-0.5 font-semibold break-all">{user?.email ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-text-dim">Phone</dt>
            <dd className="mt-0.5 font-semibold">{user?.phone ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-text-dim">Member since</dt>
            <dd className="mt-0.5 font-semibold">{formatDate(user?.created_at)}</dd>
          </div>
        </dl>
      </div>
    </div>
  );
}

function MyList() {
  const list = useList<Drama>("/me/favorites", { per_page: 60 });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>Retry</Button>} />;
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
        title="Your list is empty"
        description="Tap “My List” on any drama to save it for later."
        action={<Button href="/browse">Browse dramas</Button>}
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
  const list = useList<HistoryItem>("/me/history", { page });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>Retry</Button>} />;
  if (list.loading)
    return (
      <div className="grid gap-3 sm:grid-cols-2">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="skeleton h-28 rounded-2xl" />
        ))}
      </div>
    );
  if (!list.items.length)
    return <EmptyState icon="history" title="Nothing watched yet" description="Episodes you watch show up here so you can pick up where you left off." action={<Button href="/">Start watching</Button>} />;
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
              className="group flex gap-4 rounded-2xl border border-border bg-surface p-3 transition hover:border-text-dim/50 hover:bg-surface-2/60"
            >
              <div className="relative aspect-[3/4] w-[72px] shrink-0 overflow-hidden rounded-lg bg-surface-2">
                {h.drama.poster_url && <Image src={h.drama.poster_url} alt="" fill sizes="72px" className="object-cover" />}
                <div className="absolute inset-0 grid place-items-center bg-black/30 opacity-0 transition group-hover:opacity-100">
                  <Icon name="play" size={20} />
                </div>
              </div>
              <div className="min-w-0 flex-1 py-1">
                <h3 className="line-clamp-1 font-bold group-hover:text-primary">{h.drama.title}</h3>
                <p className="mt-1 text-xs text-text-muted">
                  Continue EP {epNo} of {h.drama.total_episodes}
                  {h.progress_seconds ? ` · at ${formatDuration(h.progress_seconds)}` : ""}
                </p>
                <div className="mt-3 h-1 overflow-hidden rounded-full bg-surface-2">
                  <div className="h-full rounded-full bg-primary" style={{ width: `${Math.max(pct, 4)}%` }} />
                </div>
                <p className="mt-2 text-[11px] text-text-dim">{formatDate(h.updated_at)}</p>
              </div>
            </Link>
          );
        })}
      </div>
      {list.meta && list.meta.last_page > 1 && (
        <div className="mt-6 flex justify-center gap-2">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            Previous
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            Next
          </Button>
        </div>
      )}
    </>
  );
}

function methodLabel(p: Payment) {
  const m = p.payment_method;
  if (m && typeof m === "object") return m.name;
  return (p.payment_method_code ?? (typeof m === "string" ? m : "")).replace(/_/g, " ");
}

function Payments() {
  const [page, setPage] = useState(1);
  const list = useList<Payment>("/me/payments", { page });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>Retry</Button>} />;
  if (list.loading) return <div className="skeleton h-64 rounded-2xl" />;
  if (!list.items.length)
    return <EmptyState icon="wallet" title="No payments yet" description="Your VIP, episode-pack and coin purchases will appear here." action={<Button href="/vip">See plans</Button>} />;
  return (
    <>
      <div className="overflow-hidden rounded-2xl border border-border bg-surface">
        <ul className="divide-y divide-border/70">
          {list.items.map((p) => (
            <li key={p.id} className="flex flex-wrap items-center gap-x-4 gap-y-1 px-4 py-3.5 sm:flex-nowrap">
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold">{p.plan?.name ?? "Purchase"}</p>
                <p className="truncate text-xs text-text-dim">
                  <span className="uppercase">{methodLabel(p)}</span> · <span className="font-mono">{p.reference}</span> · {formatDate(p.paid_at ?? p.created_at, true)}
                </p>
              </div>
              <p className="font-bold">{formatMoney(p.amount, p.currency)}</p>
              <StatusPill status={p.status} />
            </li>
          ))}
        </ul>
      </div>
      {list.meta && list.meta.last_page > 1 && (
        <div className="mt-6 flex justify-center gap-2">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            Previous
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            Next
          </Button>
        </div>
      )}
    </>
  );
}
