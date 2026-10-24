"use client";

import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/Feedback";

export default function SiteError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="mx-auto max-w-3xl px-4 pt-16">
      <EmptyState
        icon="alert"
        title="Something went wrong"
        description="We hit a snag loading this page. Please try again."
        action={<Button onClick={reset}>Try again</Button>}
      />
    </div>
  );
}
