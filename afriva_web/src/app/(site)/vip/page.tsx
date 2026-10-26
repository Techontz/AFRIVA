import type { Metadata } from "next";
import { Suspense } from "react";
import { VipCheckout } from "@/components/site/VipCheckout";
import { ApiDownState } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { asArray } from "@/lib/api";
import { T } from "@/lib/i18n";
import { serverGet } from "@/lib/server-api";
import type { PaymentMethod, Plan } from "@/lib/types";

export const metadata: Metadata = {
  title: "VIP na Coins",
  description: "Jiunge na VIP ya AFRIVA, nunua vifurushi vya episode au coins. Lipa kwa M-Pesa, Mixx by Yas, Airtel Money, HaloPesa au kadi za kimataifa.",
};

const PERKS = [
  { icon: "play", title: "Every episode", text: "No locks, no waiting" },
  { icon: "sparkles", title: "New drops daily", text: "Fresh twists every day" },
  { icon: "phone", title: "Pay your way", text: "Mobile money or international cards" },
] as const;

export default function VipPage({ searchParams }: PageProps<"/vip">) {
  return (
    <div className="relative">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-[420px] bg-[radial-gradient(ellipse_at_top,rgba(225,18,43,0.22),transparent_60%)]" />
      <div className="relative site-container pt-10">
        <div className="mx-auto max-w-2xl text-center">
          <span className="inline-flex items-center gap-1.5 rounded-full border border-primary/40 bg-primary/10 px-3 py-1 text-xs font-bold uppercase tracking-wider text-primary">
            <Icon name="crown" size={14} /> Afriva VIP
          </span>
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight sm:text-5xl">
            <T>Binge every twist.</T>{" "}
            <span className="text-primary">
              <T>Skip every lock.</T>
            </span>
          </h1>
          <p className="mt-3 text-[15px] text-text-muted">
            <T>Choose a VIP pass for unlimited watching, an episode pack, or top up coins to unlock episodes one by one.</T>
          </p>
        </div>
        <div className="mx-auto mt-8 grid max-w-3xl grid-cols-3 gap-2 sm:gap-4">
          {PERKS.map((p) => (
            <div key={p.title} className="rounded-2xl border border-border bg-surface/60 p-3 text-center sm:p-4">
              <Icon name={p.icon} className="mx-auto text-primary" />
              <p className="mt-2 text-xs font-bold sm:text-sm">
                <T>{p.title}</T>
              </p>
              <p className="mt-0.5 hidden text-xs text-text-dim sm:block">
                <T>{p.text}</T>
              </p>
            </div>
          ))}
        </div>
        <div className="mt-12">
          <Suspense fallback={<VipSkeleton />}>
            <VipContent searchParams={searchParams} />
          </Suspense>
        </div>
      </div>
    </div>
  );
}

async function VipContent({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const nextParam = typeof sp.next === "string" && sp.next.startsWith("/") && !sp.next.startsWith("//") ? sp.next : undefined;
  const [plans, methods] = await Promise.all([
    serverGet<unknown>("/plans", undefined, 120),
    serverGet<unknown>("/payment-methods", undefined, 120),
  ]);
  if (plans === null || methods === null) return <ApiDownState />;
  const planList = asArray<Plan>(plans)
    .filter((p) => p.is_active !== false)
    .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
  const methodList = asArray<PaymentMethod>(methods).sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
  return <VipCheckout plans={planList} methods={methodList} next={nextParam} />;
}

function VipSkeleton() {
  return (
    <div className="grid gap-8 lg:grid-cols-[1fr_420px]">
      <div className="grid grid-cols-1 gap-3 min-[420px]:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="skeleton h-52 rounded-2xl" />
        ))}
      </div>
      <div className="skeleton h-[520px] rounded-3xl" />
    </div>
  );
}
