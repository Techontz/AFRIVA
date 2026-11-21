"use client";

import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";

/** Fired by our router wrapper (src/lib/navigation.ts) before a programmatic navigation. */
export const NAV_START_EVENT = "afriva:nav-start";

export function startNavProgress() {
  if (typeof window !== "undefined") window.dispatchEvent(new Event(NAV_START_EVENT));
}

/** True for a click that will make Next.js navigate to another page of this site. */
function isInternalNavigation(e: MouseEvent): boolean {
  if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return false;
  const a = (e.target as Element | null)?.closest?.("a[href]") as HTMLAnchorElement | null;
  if (!a || a.target === "_blank" || a.hasAttribute("download") || a.dataset.noProgress !== undefined) return false;
  const url = new URL(a.href, window.location.href);
  if (url.origin !== window.location.origin) return false;
  // Same page (or only a #hash change): nothing will load.
  return url.pathname !== window.location.pathname || url.search !== window.location.search;
}

/**
 * Thin red bar across the top of the window while a page is loading, so every tap gets instant feedback.
 * Starts on internal link clicks, back/forward and programmatic navigations; finishes when the URL changes.
 */
export function NavProgress() {
  const pathname = usePathname();
  const search = useSearchParams();
  const [progress, setProgress] = useState(0); // 0 = hidden
  const [fading, setFading] = useState(false);
  const active = useRef(false);
  const timers = useRef<number[]>([]);

  const clear = () => {
    timers.current.forEach((t) => window.clearTimeout(t));
    timers.current = [];
  };

  const start = () => {
    clear();
    active.current = true;
    setFading(false);
    setProgress(8);
    // Trickle towards 90% while waiting; it never reaches 100% on its own.
    const step = (value: number) => {
      if (!active.current) return;
      setProgress(value);
      const next = value + (90 - value) * 0.12;
      timers.current.push(window.setTimeout(() => step(next), 220));
    };
    timers.current.push(window.setTimeout(() => step(25), 60));
    // Safety net: never leave a bar hanging (e.g. a navigation that was cancelled).
    timers.current.push(window.setTimeout(() => done(), 15000));
  };

  const done = () => {
    if (!active.current) return;
    active.current = false;
    clear();
    setProgress(100);
    timers.current.push(window.setTimeout(() => setFading(true), 180));
    timers.current.push(
      window.setTimeout(() => {
        setProgress(0);
        setFading(false);
      }, 480),
    );
  };

  // Finish when the visible URL changes.
  useEffect(() => {
    done();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname, search]);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (isInternalNavigation(e)) start();
    };
    const onPop = () => start();
    const onStart = () => start();
    // Capture phase so we see the click before Next's <Link> handles it.
    document.addEventListener("click", onClick, true);
    window.addEventListener("popstate", onPop);
    window.addEventListener(NAV_START_EVENT, onStart);
    return () => {
      document.removeEventListener("click", onClick, true);
      window.removeEventListener("popstate", onPop);
      window.removeEventListener(NAV_START_EVENT, onStart);
      clear();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (progress === 0) return null;
  return (
    <div aria-hidden className="pointer-events-none fixed inset-x-0 top-0 z-[2147483647] h-[3px]">
      <div
        className="h-full bg-primary shadow-[0_0_10px_rgba(233,2,4,0.7),0_0_4px_rgba(233,2,4,0.6)]"
        style={{
          width: `${progress}%`,
          opacity: fading ? 0 : 1,
          transition: "width 220ms ease-out, opacity 300ms ease",
        }}
      />
    </div>
  );
}
