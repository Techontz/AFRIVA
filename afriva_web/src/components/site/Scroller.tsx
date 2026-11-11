"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { useT } from "@/i18n/client";
import { cn } from "@/lib/format";
import { Icon } from "../ui/Icon";

/**
 * Horizontal shelf: swipe on touch, edge fades and arrows on desktop. The arrows and fades only
 * appear on a side that really has more content, and the children render on the server.
 */
export function Scroller({ label, children, className }: { label: string; children: ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const [edges, setEdges] = useState({ start: true, end: false });
  const t = useT().site.card;

  const measure = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    const start = el.scrollLeft <= 2;
    const end = el.scrollLeft + el.clientWidth >= el.scrollWidth - 2;
    setEdges((e) => (e.start === start && e.end === end ? e : { start, end }));
  }, []);

  useEffect(() => {
    measure();
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [measure]);

  const page = (dir: 1 | -1) => {
    const el = ref.current;
    if (!el) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    el.scrollBy({ left: dir * el.clientWidth * 0.86, behavior: reduced ? "auto" : "smooth" });
  };

  return (
    <div className="group/scroller relative" role="group" aria-label={label}>
      <div
        ref={ref}
        onScroll={measure}
        data-start={edges.start || undefined}
        data-end={edges.end || undefined}
        className={cn(
          "edge-fade scrollbar-none -mx-4 -my-3 flex snap-x snap-proximity scroll-pl-4 gap-3 overflow-x-auto overscroll-x-contain px-4 py-3 sm:-mx-6 sm:scroll-pl-6 sm:gap-3.5 sm:px-6 lg:mx-0 lg:scroll-pl-0 lg:gap-[18px] lg:px-0",
          className,
        )}
      >
        {children}
      </div>
      {!edges.start && <ScrollArrow dir="left" label={t.scrollBack} onClick={() => page(-1)} />}
      {!edges.end && <ScrollArrow dir="right" label={t.scrollForward} onClick={() => page(1)} />}
    </div>
  );
}

function ScrollArrow({ dir, label, onClick }: { dir: "left" | "right"; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        "absolute top-[34%] z-10 hidden size-11 place-items-center rounded-full bg-black/60 text-white opacity-0 ring-1 ring-white/10 backdrop-blur-xl transition duration-200 hover:scale-105 hover:bg-black/80 focus-visible:opacity-100 group-hover/scroller:opacity-100 lg:grid",
        dir === "left" ? "-left-3" : "-right-3",
      )}
    >
      <Icon name={dir === "left" ? "chevron-left" : "chevron-right"} size={22} strokeWidth={2.2} />
    </button>
  );
}
