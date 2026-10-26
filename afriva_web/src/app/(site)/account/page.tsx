import type { Metadata } from "next";
import { Suspense } from "react";
import { AccountView } from "@/components/site/AccountView";

export const metadata: Metadata = { title: "Profile" };

export default function AccountPage() {
  return (
    <Suspense fallback={<div className="skeleton mx-auto mt-8 h-40 max-w-[1200px] rounded-3xl" />}>
      <AccountView />
    </Suspense>
  );
}
