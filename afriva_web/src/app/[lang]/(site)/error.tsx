"use client";

import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/Feedback";
import { useT } from "@/i18n/client";

export default function SiteError({ reset }: { error: Error; reset: () => void }) {
  const t = useT().common.feedback;
  return (
    <div className="mx-auto max-w-3xl px-4 pt-16">
      <EmptyState
        icon="alert"
        title={t.errorTitle}
        description={t.errorBody}
        action={<Button onClick={reset}>{t.tryAgain}</Button>}
      />
    </div>
  );
}
