import type { Metadata } from "next";
import { Suspense } from "react";
import { AuthForm } from "@/components/site/AuthForm";
import { getDict } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getDict()).site.meta.login };
}

export default function Page() {
  return (
    <Suspense fallback={<div className="min-h-[70vh]" />}>
      <AuthForm mode="login" />
    </Suspense>
  );
}
