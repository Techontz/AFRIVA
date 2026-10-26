"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { api, errorMessage } from "@/lib/api";
import { useApi, useList } from "@/lib/hooks";
import { useAuth } from "@/lib/auth";
import { LANGS, useLang, useT } from "@/lib/i18n";
import { cn, formatDate, formatDuration, formatMoney, formatNumber, initials } from "@/lib/format";
import type { CoinTransaction, Drama, HistoryItem, Payment, Receipt, Subscription } from "@/lib/types";
import { RoleGuard } from "../RoleGuard";
import { Button } from "../ui/Button";
import { ApiDownState, EmptyState, Spinner, StatusPill } from "../ui/Feedback";
import { Field, Input, Textarea } from "../ui/Form";
import { Icon, type IconName } from "../ui/Icon";
import { Modal } from "../ui/Modal";
import { PosterCard, PosterCardSkeleton, gridClass } from "./PosterCard";

const SUPPORT_EMAIL = "support@afriva.com";

/** Profile sections from scope §03: coins, VIP, historia, vipendwa, akaunti, lugha, msaada, miamala. */
const TABS: { key: string; label: string; icon: IconName }[] = [
  { key: "overview", label: "Overview", icon: "user" },
  { key: "coins", label: "Coins", icon: "coin" },
  { key: "list", label: "Favorites", icon: "bookmark" },
  { key: "history", label: "History", icon: "history" },
  { key: "payments", label: "Transactions", icon: "wallet" },
  { key: "settings", label: "Account & help", icon: "settings" },
  { key: "creator", label: "Submit your work", icon: "upload" },
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
  const t = useT();
  const params = useSearchParams();
  const router = useRouter();
  const tab = TABS.some((x) => x.key === params.get("tab")) ? params.get("tab")! : "overview";
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
            <Icon name="coin" size={15} /> {t("Top up")}
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={async () => {
              await logout();
              router.push("/");
            }}
          >
            <Icon name="logout" size={15} /> {t("Log out")}
          </Button>
        </div>
      </div>

      <div className="scrollbar-none sticky top-16 lg:top-[88px] z-20 -mx-4 mt-6 flex gap-1 overflow-x-auto border-b border-border bg-bg/85 px-4 backdrop-blur-xl sm:mx-0 sm:px-0" role="tablist">
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
            <Icon name={x.icon} size={16} /> {t(x.label)}
            {tab === x.key && <span className="absolute inset-x-3 bottom-0 h-0.5 rounded-full bg-primary" />}
          </Link>
        ))}
      </div>

      <div className="mt-6">
        {tab === "overview" && <Overview />}
        {tab === "coins" && <Coins />}
        {tab === "list" && <MyList />}
        {tab === "history" && <History />}
        {tab === "payments" && <Payments initialReceipt={params.get("receipt")} />}
        {tab === "settings" && <SettingsTab />}
        {tab === "creator" && <CreatorTab />}
      </div>
    </div>
  );
}

function Overview() {
  const { user } = useAuth();
  const t = useT();
  const sub = useApi<Subscription | null>("/me/subscription");
  const meta = (sub.meta ?? {}) as Record<string, unknown>;
  const active = sub.data ?? user?.active_subscription ?? null;
  const coins = typeof meta.coins === "number" ? meta.coins : user?.coins ?? 0;
  const episodesRemaining = Number(meta.episodes_remaining ?? active?.episodes_remaining ?? 0);

  return (
    <div className="grid gap-4 md:grid-cols-3">
      <div className="rounded-2xl border border-border bg-surface p-5">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Coin balance")}</p>
        <p className="mt-2 flex items-center gap-2 text-3xl font-extrabold text-primary">
          <Icon name="coin" size={28} /> {formatNumber(coins)}
        </p>
        <p className="mt-1 text-xs text-text-muted">{t("Use coins to unlock single episodes.")}</p>
        <div className="mt-4 flex gap-4 text-sm font-semibold">
          <Link href="/vip#coins" className="text-primary hover:underline">
            {t("Buy coins →")}
          </Link>
          <Link href="/account?tab=coins" className="text-text-muted hover:text-text">
            {t("Coin history")}
          </Link>
        </div>
      </div>
      <div className="rounded-2xl border border-border bg-surface p-5 md:col-span-2">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Subscription")}</p>
        {sub.loading ? (
          <div className="skeleton mt-3 h-14 rounded-xl" />
        ) : active && active.type !== "episodes" ? (
          <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="flex items-center gap-2 text-xl font-extrabold">
                <Icon name="crown" className="text-primary" /> {active.plan?.name ?? t("{type} VIP", { type: t(active.type) })}
              </p>
              <p className="mt-1 text-sm text-text-muted">
                {t("Active since {date}", { date: formatDate(active.starts_at) })} ·{" "}
                {active.ends_at ? t("renews manually on {date}", { date: formatDate(active.ends_at) }) : t("no expiry")}
              </p>
            </div>
            <StatusPill status={active.status} />
          </div>
        ) : (
          <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-xl font-extrabold">{t("Free plan")}</p>
              <p className="mt-1 text-sm text-text-muted">{t("Unlock every episode with VIP from 3,000 TZS/week.")}</p>
            </div>
            <Button href="/vip" size="sm">
              <Icon name="crown" size={15} /> {t("Go VIP")}
            </Button>
          </div>
        )}
        {episodesRemaining > 0 && (
          <p className="mt-4 flex items-center gap-2 rounded-xl bg-surface-2 p-3 text-sm">
            <Icon name="layers" size={17} className="text-primary" /> {t("{n} episode unlocks left in your pack", { n: episodesRemaining })}
          </p>
        )}
      </div>
      <div className="rounded-2xl border border-border bg-surface p-5 md:col-span-3">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Profile")}</p>
        <dl className="mt-3 grid gap-4 text-sm sm:grid-cols-3">
          <div>
            <dt className="text-text-dim">{t("Name")}</dt>
            <dd className="mt-0.5 font-semibold">{user?.name}</dd>
          </div>
          <div>
            <dt className="text-text-dim">{t("Email")}</dt>
            <dd className="mt-0.5 font-semibold break-all">{user?.email ?? "-"}</dd>
          </div>
          <div>
            <dt className="text-text-dim">{t("Phone")}</dt>
            <dd className="mt-0.5 font-semibold">{user?.phone ?? "-"}</dd>
          </div>
          <div>
            <dt className="text-text-dim">{t("Member since")}</dt>
            <dd className="mt-0.5 font-semibold">{formatDate(user?.created_at)}</dd>
          </div>
        </dl>
      </div>
    </div>
  );
}

function MyList() {
  const t = useT();
  const list = useList<Drama>("/me/favorites", { per_page: 60 });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t("Retry")}</Button>} />;
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
        title={t("Your list is empty")}
        description={t("Tap “My List” on any drama to save it for later.")}
        action={<Button href="/browse">{t("Browse dramas")}</Button>}
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
  const t = useT();
  const [page, setPage] = useState(1);
  const list = useList<HistoryItem>("/me/history", { page });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t("Retry")}</Button>} />;
  if (list.loading)
    return (
      <div className="grid gap-3 sm:grid-cols-2">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="skeleton h-28 rounded-2xl" />
        ))}
      </div>
    );
  if (!list.items.length)
    return <EmptyState icon="history" title={t("Nothing watched yet")} description={t("Episodes you watch show up here so you can pick up where you left off.")} action={<Button href="/">{t("Start watching")}</Button>} />;
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
                  {t("Continue EP {n} of {total}", { n: epNo, total: h.drama.total_episodes })}
                  {h.progress_seconds ? ` · ${t("at {time}", { time: formatDuration(h.progress_seconds) })}` : ""}
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
            {t("Previous")}
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            {t("Next")}
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

function Payments({ initialReceipt }: { initialReceipt: string | null }) {
  const t = useT();
  const [page, setPage] = useState(1);
  const [receiptRef, setReceiptRef] = useState<string | null>(initialReceipt);
  const list = useList<Payment>("/me/payments", { page });
  if (list.error) return <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t("Retry")}</Button>} />;
  if (list.loading) return <div className="skeleton h-64 rounded-2xl" />;
  if (!list.items.length)
    return <EmptyState icon="wallet" title={t("No payments yet")} description={t("Your VIP, episode-pack and coin purchases will appear here.")} action={<Button href="/vip">{t("See plans")}</Button>} />;
  return (
    <>
      <div className="overflow-hidden rounded-2xl border border-border bg-surface">
        <ul className="divide-y divide-border/70">
          {list.items.map((p) => (
            <li key={p.id} className="flex flex-wrap items-center gap-x-4 gap-y-1 px-4 py-3.5 sm:flex-nowrap">
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold">{p.plan?.name ?? t("Purchase")}</p>
                <p className="truncate text-xs text-text-dim">
                  <span className="uppercase">{methodLabel(p)}</span> · <span className="font-mono">{p.reference}</span> · {formatDate(p.paid_at ?? p.created_at, true)}
                </p>
              </div>
              <p className="font-bold">{formatMoney(p.amount, p.currency)}</p>
              <StatusPill status={p.status} />
              {(p.status === "success" || p.status === "refunded") && (
                <Button variant="ghost" size="sm" onClick={() => setReceiptRef(p.reference)}>
                  <Icon name="list" size={14} /> {t("Receipt")}
                </Button>
              )}
            </li>
          ))}
        </ul>
      </div>
      {list.meta && list.meta.last_page > 1 && (
        <div className="mt-6 flex justify-center gap-2">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            {t("Previous")}
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            {t("Next")}
          </Button>
        </div>
      )}
      <ReceiptModal reference={receiptRef} onClose={() => setReceiptRef(null)} />
    </>
  );
}

/** Printable receipt (scope §07: "risiti na rekodi ya transaction"). */
function ReceiptModal({ reference, onClose }: { reference: string | null; onClose: () => void }) {
  const t = useT();
  const receipt = useApi<Receipt>(reference ? `/me/payments/${encodeURIComponent(reference)}/receipt` : null);
  return (
    <Modal open={!!reference} onClose={onClose} title={t("Receipt")}>
      {receipt.loading ? (
        <div className="grid place-items-center py-10">
          <Spinner size={28} />
        </div>
      ) : receipt.error || !receipt.data ? (
        <p className="py-6 text-center text-sm text-text-muted">{receipt.error ? errorMessage(receipt.error) : t("Receipt not found.")}</p>
      ) : (
        <div className="print-area space-y-4 text-sm">
          <div className="flex items-start justify-between gap-4 border-b border-border pb-4">
            <div>
              <p className="text-lg font-extrabold">{receipt.data.seller.name}</p>
              {receipt.data.seller.email && <p className="text-xs text-text-dim">{receipt.data.seller.email}</p>}
            </div>
            <div className="text-right">
              <p className="font-mono text-xs font-bold">{receipt.data.receipt_number ?? "-"}</p>
              <p className="text-xs text-text-dim">{formatDate(receipt.data.issued_at, true)}</p>
            </div>
          </div>
          <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
            <dt className="text-text-dim">{t("Customer")}</dt>
            <dd className="text-right font-semibold">{receipt.data.customer.name ?? "-"}</dd>
            <dt className="text-text-dim">{t("Package")}</dt>
            <dd className="text-right font-semibold">{receipt.data.item.name ?? "-"}</dd>
            {receipt.data.item.delivered && (
              <>
                <dt className="text-text-dim">{t("You received")}</dt>
                <dd className="text-right font-semibold">{receipt.data.item.delivered}</dd>
              </>
            )}
            <dt className="text-text-dim">{t("Payment method")}</dt>
            <dd className="text-right font-semibold">{receipt.data.payment_method.name}</dd>
            <dt className="text-text-dim">{t("Reference")}</dt>
            <dd className="text-right font-mono text-xs">{receipt.data.reference}</dd>
            {receipt.data.provider_reference && (
              <>
                <dt className="text-text-dim">{t("Provider reference")}</dt>
                <dd className="text-right font-mono text-xs">{receipt.data.provider_reference}</dd>
              </>
            )}
            <dt className="text-text-dim">{t("Status")}</dt>
            <dd className="text-right">
              <StatusPill status={receipt.data.status} />
            </dd>
          </dl>
          <div className="flex items-center justify-between border-t border-border pt-4 text-base">
            <span className="font-bold">{t("Total paid")}</span>
            <span className="font-extrabold">{formatMoney(receipt.data.amount, receipt.data.currency)}</span>
          </div>
          {receipt.data.refunded_amount > 0 && (
            <p className="flex justify-between text-sm text-text-muted">
              <span>{t("Refunded")}</span>
              <span>-{formatMoney(receipt.data.refunded_amount, receipt.data.currency)}</span>
            </p>
          )}
          <div className="flex justify-end gap-2 pt-2 print:hidden">
            <Button variant="secondary" size="sm" onClick={() => window.print()}>
              {t("Print")}
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
}

const COIN_TYPE_LABEL: Record<CoinTransaction["type"], string> = {
  purchase: "Coins purchased",
  bonus: "Bonus coins",
  unlock: "Episode unlocked",
  admin_adjust: "Adjusted by AFRIVA",
  refund: "Refund",
};

function Coins() {
  const t = useT();
  const [page, setPage] = useState(1);
  const list = useList<CoinTransaction>("/me/coins", { page });
  const { user } = useAuth();
  const balance = typeof (list.meta as unknown as { balance?: number } | null)?.balance === "number"
    ? (list.meta as unknown as { balance: number }).balance
    : user?.coins ?? 0;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-border bg-surface p-5">
        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Coin balance")}</p>
          <p className="mt-1 flex items-center gap-2 text-3xl font-extrabold text-primary">
            <Icon name="coin" size={28} /> {formatNumber(balance)}
          </p>
        </div>
        <Button href="/vip#coins" variant="gold" size="sm">
          <Icon name="coin" size={15} /> {t("Top up")}
        </Button>
      </div>
      {list.error ? (
        <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t("Retry")}</Button>} />
      ) : list.loading ? (
        <div className="skeleton h-64 rounded-2xl" />
      ) : !list.items.length ? (
        <EmptyState icon="coin" title={t("No coin activity yet")} description={t("Coins you buy and spend on episodes appear here.")} />
      ) : (
        <div className="overflow-hidden rounded-2xl border border-border bg-surface">
          <ul className="divide-y divide-border/70">
            {list.items.map((c) => (
              <li key={c.id} className="flex items-center gap-4 px-4 py-3">
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{t(COIN_TYPE_LABEL[c.type] ?? c.type)}</p>
                  <p className="truncate text-xs text-text-dim">
                    {c.episode?.drama ? `${c.episode.drama.title} · ${t("EP {n}", { n: c.episode.number })}` : c.description ?? ""}
                    {" · "}
                    {formatDate(c.created_at, true)}
                  </p>
                </div>
                <div className="text-right">
                  <p className={cn("font-bold", c.amount >= 0 ? "text-success" : "text-text")}>
                    {c.amount >= 0 ? "+" : ""}
                    {formatNumber(c.amount)}
                  </p>
                  <p className="text-[11px] text-text-dim">{t("Balance {n}", { n: formatNumber(c.balance_after) })}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
      {list.meta && list.meta.last_page > 1 && (
        <div className="flex justify-center gap-2">
          <Button variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>
            {t("Previous")}
          </Button>
          <Button variant="secondary" size="sm" disabled={page >= list.meta.last_page} onClick={() => setPage(page + 1)}>
            {t("Next")}
          </Button>
        </div>
      )}
    </div>
  );
}

/** Akaunti, lugha, msaada. */
function SettingsTab() {
  const t = useT();
  const { user } = useAuth();
  const { lang, setLang } = useLang();
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <div className="rounded-2xl border border-border bg-surface p-5">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Account")}</p>
        <dl className="mt-3 space-y-3 text-sm">
          <div className="flex justify-between gap-4">
            <dt className="text-text-dim">{t("Name")}</dt>
            <dd className="font-semibold">{user?.name}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-text-dim">{t("Email")}</dt>
            <dd className="break-all font-semibold">{user?.email ?? "-"}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-text-dim">{t("Phone")}</dt>
            <dd className="font-semibold">{user?.phone ?? "-"}</dd>
          </div>
        </dl>
        <p className="mt-4 text-xs text-text-dim">{t("To change your details or delete your account, contact support.")}</p>
      </div>
      <div className="rounded-2xl border border-border bg-surface p-5">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Language")}</p>
        <div className="mt-3 flex gap-2" role="radiogroup" aria-label={t("Language")}>
          {LANGS.map((l) => (
            <button
              key={l.code}
              role="radio"
              aria-checked={lang === l.code}
              onClick={() => setLang(l.code)}
              className={cn(
                "rounded-full px-4 py-2 text-sm font-semibold transition",
                lang === l.code ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:text-text",
              )}
            >
              {l.label}
            </button>
          ))}
        </div>
        <p className="mt-3 text-xs text-text-dim">{t("AFRIVA is in Kiswahili. Series titles may be in other languages.")}</p>
      </div>
      <div className="rounded-2xl border border-border bg-surface p-5 md:col-span-2">
        <p className="text-xs font-bold uppercase tracking-wider text-text-dim">{t("Help")}</p>
        <ul className="mt-3 space-y-2 text-sm">
          <li>
            <a href={`mailto:${SUPPORT_EMAIL}`} className="flex items-center gap-2 font-semibold text-primary hover:underline">
              <Icon name="mail" size={16} /> {SUPPORT_EMAIL}
            </a>
          </li>
          <li className="text-text-muted">{t("Payment problem? Include the payment reference from your transactions.")}</li>
          <li>
            <Link href="/info/terms" className="text-text-muted hover:text-text">
              {t("Terms of Use")}
            </Link>
            {" · "}
            <Link href="/info/privacy" className="text-text-muted hover:text-text">
              {t("Privacy Policy")}
            </Link>
          </li>
        </ul>
      </div>
    </div>
  );
}

/** "Wasilisha Kazi Yako" (scope §04): viewers apply to become creators; creators go to the Studio. */
function CreatorTab() {
  const t = useT();
  const { user, refresh } = useAuth();
  const [form, setForm] = useState({ name: "", phone: user?.phone ?? "", description: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const steps = [
    { title: "1. Submit", text: "Series or episodes, cover, trailer, video, description and genre." },
    { title: "2. Review", text: "AFRIVA checks quality, rights and all details." },
    { title: "3. Fix", text: "You get feedback and can send a new version if changes are needed." },
    { title: "4. Publish", text: "After approval, AFRIVA sets the date, price and free episodes." },
  ];

  if (user?.role === "super_admin") {
    return <EmptyState icon="shield" title={t("Staff accounts can't submit work")} action={<Button href="/admin">{t("Admin portal")}</Button>} />;
  }

  const apply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name.trim()) {
      setError(t("Enter your studio or creator name."));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const res = await api.post<{ message?: string }>("/creator/apply", {
        name: form.name.trim(),
        phone: form.phone.trim() || null,
        description: form.description.trim() || null,
      });
      toast.success(res?.message ?? t("Application received."));
      await refresh();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-border bg-surface p-5">
        <h2 className="text-lg font-extrabold">{t("Submit your work to AFRIVA")}</h2>
        <p className="mt-1 text-sm text-text-muted">
          {t("Uploading does not publish your work: every video is reviewed and its playback tested before it is approved.")}
        </p>
        <ol className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((s) => (
            <li key={s.title} className="rounded-xl bg-surface-2 p-3">
              <p className="text-sm font-bold">{t(s.title)}</p>
              <p className="mt-1 text-xs text-text-muted">{t(s.text)}</p>
            </li>
          ))}
        </ol>
        <p className="mt-4 text-xs text-text-dim">
          {t("Before publishing you confirm you own the rights, and accept the creator revenue agreement.")}
        </p>
      </div>

      {user?.role === "company" ? (
        <div className="rounded-2xl border border-primary/40 bg-primary/10 p-5">
          <p className="font-bold">{user.company?.name}</p>
          <p className="mt-1 text-sm text-text-muted">
            {user.company?.status === "pending"
              ? t("Your creator account is being reviewed. You can prepare drafts now and submit them once it is approved.")
              : t("Your creator account is active. Manage your series in the Studio.")}
          </p>
          <Button href="/studio" className="mt-4">
            <Icon name="film" size={16} /> {t("Open Creator Studio")}
          </Button>
        </div>
      ) : (
        <form onSubmit={apply} className="space-y-4 rounded-2xl border border-border bg-surface p-5">
          <h3 className="font-bold">{t("Become a creator")}</h3>
          <Field label="Studio or creator name" htmlFor="creator-name">
            <Input id="creator-name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} maxLength={120} />
          </Field>
          <Field label="Phone" htmlFor="creator-phone">
            <Input id="creator-phone" type="tel" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="+255 7XX XXX XXX" />
          </Field>
          <Field label="About your work (optional)" htmlFor="creator-about">
            <Textarea id="creator-about" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} maxLength={2000} />
          </Field>
          {error && <p className="text-sm font-medium text-danger">{error}</p>}
          <Button type="submit" loading={busy}>
            <Icon name="upload" size={16} /> {t("Apply as a creator")}
          </Button>
        </form>
      )}
    </div>
  );
}
