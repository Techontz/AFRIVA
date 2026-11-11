"use client";

import { useAuth } from "@/lib/auth";
import { ApplicationStatus } from "../site/ApplicationStatus";

/** Studio stays locked until Afriva approves the request to post: pending logins only see their application. */
export function StudioGate({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  if (user && user.role === "company" && user.status === "pending") return <ApplicationStatus inStudio />;
  return <>{children}</>;
}
