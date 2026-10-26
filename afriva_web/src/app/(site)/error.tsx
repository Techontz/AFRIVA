"use client";

import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/Feedback";
import { useT } from "@/lib/i18n";

export default function SiteError({ reset }: { error: Error; reset: () => void }) {
  const t = useT();
  return (
    <div className="mx-auto max-w-3xl px-4 pt-16">
      <EmptyState
        icon="alert"
        title={t("Something went wrong")}
        description={t("We hit a snag loading this page. Please try again.")}
        action={<Button onClick={reset}>{t("Try again")}</Button>}
      />
    </div>
  );
}
