"use client";

import { useRouter as useNextRouter } from "next/navigation";
import { useMemo } from "react";
import { startNavProgress } from "@/components/ui/NavProgress";

/** next/navigation's useRouter, but push/replace also show the top loading bar. */
export function useRouter() {
  const router = useNextRouter();
  return useMemo(
    () => ({
      ...router,
      push: (...args: Parameters<typeof router.push>) => {
        startNavProgress();
        return router.push(...args);
      },
      replace: (...args: Parameters<typeof router.replace>) => {
        startNavProgress();
        return router.replace(...args);
      },
    }),
    [router],
  );
}
