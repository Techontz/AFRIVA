import type { Metadata } from "next";
import { Suspense } from "react";
import { AuthForm } from "@/components/site/AuthForm";

export const metadata: Metadata = { title: "Ingia" };

export default function Page() {
  return (
    <Suspense fallback={<div className="min-h-[70vh]" />}>
      <AuthForm mode="login" />
    </Suspense>
  );
}
