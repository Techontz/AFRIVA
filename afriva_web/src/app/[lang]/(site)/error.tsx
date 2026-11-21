"use client";

import { useRouter } from "next/navigation";
import { startTransition, useEffect } from "react";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/Feedback";
import { useT } from "@/i18n/client";

const RELOAD_KEY = "afriva:chunk-reload-at";

/** A page file (JS chunk) could not be loaded, typically right after a new version was deployed. */
function isChunkError(error: Error): boolean {
  const text = `${error?.name ?? ""} ${error?.message ?? ""}`;
  return /ChunkLoadError|Loading chunk|Failed to load chunk|dynamically imported module|Importing a module script failed/i.test(text);
}

export default function SiteError({ error, reset }: { error: Error; reset: () => void }) {
  const t = useT().common.feedback;
  const router = useRouter();

  // Recover by itself from a missing chunk with one full reload (guarded so it can never loop).
  useEffect(() => {
    if (!isChunkError(error)) return;
    try {
      const last = Number(sessionStorage.getItem(RELOAD_KEY) || 0);
      if (Date.now() - last < 30_000) return;
      sessionStorage.setItem(RELOAD_KEY, String(Date.now()));
    } catch {
      // Storage unavailable: still reload once; the effect does not rerun on the reloaded page's success.
    }
    window.location.reload();
  }, [error]);

  // Fetch the page again from the server, then re-render (a plain reset only re-renders what is cached).
  const retry = () =>
    startTransition(() => {
      router.refresh();
      reset();
    });

  return (
    <div className="mx-auto max-w-3xl px-4 pt-16">
      <EmptyState
        icon="alert"
        title={t.errorTitle}
        description={t.errorBody}
        action={<Button onClick={retry}>{t.tryAgain}</Button>}
      />
    </div>
  );
}
