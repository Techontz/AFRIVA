import type { Metadata } from "next";
import { Suspense } from "react";
import { AuthForm } from "@/components/site/AuthForm";

export const metadata: Metadata = { title: "Sign up" };

export default function Page() {
  return (
    <Suspense fallback={<div className="min-h-[70vh]" />}>
      <AuthForm mode="register" />
    </Suspense>
  );
}
