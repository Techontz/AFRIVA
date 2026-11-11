import type { Metadata } from "next";
import { Suspense } from "react";
import { AccountView } from "@/components/site/AccountView";
import { getDict } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getDict()).site.meta.account, robots: { index: false } };
}

export default function AccountPage() {
  return (
    <Suspense fallback={<div className="skeleton mx-auto mt-8 h-40 max-w-[1200px] rounded-3xl" />}>
      <AccountView />
    </Suspense>
  );
}
