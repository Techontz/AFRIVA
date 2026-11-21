import type { Metadata } from "next";
import { Suspense } from "react";
import { VipCheckout } from "@/components/site/VipCheckout";
import { ApiDownState } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { getDict } from "@/i18n/server";
import { asArray } from "@/lib/api";
import { safeNextPath } from "@/lib/format";
import { serverGet } from "@/lib/server-api";
import { parsePaymentReturn, type CheckoutOptions } from "@/lib/payments";
import type { Plan } from "@/lib/types";

export async function generateMetadata(): Promise<Metadata> {
  return { title: "VIP", description: (await getDict()).site.vip.metaDescription };
}

const PERKS = [
  { key: "every" },
  { key: "daily" },
  { key: "pay" },
] as const;

export default async function VipPage({ searchParams }: PageProps<"/[lang]/vip">) {
  const t = (await getDict()).site.vip;
  return (
    <div className="relative">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-[420px] -top-(--header-h) bg-[radial-gradient(ellipse_at_top,rgba(233,2,4,0.22),transparent_60%)]" />
      <div className="relative site-container pt-8 lg:pt-14">
        <div className="mx-auto max-w-2xl text-center">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-primary/15 px-3 py-1 text-xs font-semibold text-primary">
            {t.badge}
          </span>
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight sm:text-5xl">
            {t.headline} <span className="block text-primary">{t.headlineAccent}</span>
          </h1>
          <p className="mt-3 text-[15px] text-text-muted">
            {t.intro}
          </p>
        </div>
        <ul className="mx-auto mt-6 flex max-w-3xl flex-wrap justify-center gap-x-8 gap-y-2 text-[13px] text-text-muted">
          {PERKS.map((p) => (
            <li key={p.key} className="flex items-center gap-2">
              <Icon name="check" size={15} className="text-primary" strokeWidth={2.4} />
              <span>
                <span className="font-semibold text-text">{t.perks[p.key].title}</span>
                <span className="hidden sm:inline"> · {t.perks[p.key].text}</span>
              </span>
            </li>
          ))}
        </ul>
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
  const nextParam = (typeof sp.next === "string" && safeNextPath(sp.next)) || undefined;
  // Back from the card provider's hosted page: /vip?payment=AFV-...(&cancelled=1).
  const paymentReturn = parsePaymentReturn(sp.payment, sp.cancelled);
  const [plans, options] = await Promise.all([
    serverGet<unknown>("/plans", undefined, 120),
    serverGet<CheckoutOptions>("/checkout/options", undefined, 60),
  ]);
  if (plans === null) return <ApiDownState />;
  const planList = asArray<Plan>(plans)
    .filter((p) => p.is_active !== false)
    .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
  // Options load in the browser when the server could not fetch them.
  return <VipCheckout plans={planList} options={options} next={nextParam} paymentReturn={paymentReturn} />;
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
