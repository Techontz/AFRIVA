"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { homeForRole, useAuth } from "@/lib/auth";
import type { Role } from "@/lib/types";
import { Spinner } from "./ui/Feedback";
import { LogoMark } from "./ui/Logo";

/** Client-side route guard. Renders children only for the allowed roles. */
export function RoleGuard({ roles, children }: { roles?: Role[]; children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const allowed = !!user && (!roles || roles.includes(user.role));

  useEffect(() => {
    if (loading) return;
    if (!user) router.replace(`/login?next=${encodeURIComponent(pathname)}`);
    else if (!allowed) router.replace(homeForRole(user.role));
  }, [loading, user, allowed, router, pathname]);

  if (!allowed) {
    return (
      <div className="grid min-h-[60vh] flex-1 place-items-center">
        <div className="flex flex-col items-center gap-4 text-text-muted">
          <LogoMark size={40} />
          <Spinner />
        </div>
      </div>
    );
  }
  return <>{children}</>;
}
