"use client";

import { usePathname } from "next/navigation";
import { useEffect } from "react";
import { useApi } from "@/lib/hooks";
import type { CreatorAgreement } from "@/lib/types";
import { Notice } from "../portal/ScopeKit";
import { Button } from "../ui/Button";
import { useT } from "@/lib/i18n";

export const STUDIO_REFRESH = "afriva:studio-refresh";

/** Creator account state (approval + revenue agreement); reloads when the agreement is accepted. */
export function useAgreement() {
  const res = useApi<CreatorAgreement>("/studio/agreement");
  const { reload } = res;
  useEffect(() => {
    window.addEventListener(STUDIO_REFRESH, reload);
    return () => window.removeEventListener(STUDIO_REFRESH, reload);
  }, [reload]);
  return res;
}

/** Banner on every Studio page while the creator is pending approval or hasn't accepted the agreement. */
export function StudioNotice() {
  const t = useT();
  const pathname = usePathname();
  const { data } = useAgreement();
  if (!data) return null;

  if (data.company_status === "pending") {
    return (
      <Notice tone="warning" icon="clock" title="Your creator account is being reviewed" className="mb-6">
        {t("You can prepare series and episodes now. You'll be able to send them for review once AFRIVA approves your account.")}
      </Notice>
    );
  }
  if (data.company_status === "suspended") {
    return (
      <Notice tone="danger" title="Your creator account is suspended" className="mb-6">
        {t("Contact AFRIVA support for help.")}
      </Notice>
    );
  }
  if (!data.accepted && pathname !== "/studio/agreement") {
    return (
      <Notice
        tone="info"
        icon="shield"
        title="Accept the revenue agreement"
        className="mb-6"
        action={
          <Button href="/studio/agreement" size="sm">
            {t("Read and accept")}
          </Button>
        }
      >
        {t("You must accept the creator revenue agreement before sending work for review.")}
      </Notice>
    );
  }
  return null;
}
