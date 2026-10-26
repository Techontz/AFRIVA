"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { useT } from "@/lib/i18n";
import { Icon } from "../ui/Icon";

export function SearchForm({ initial }: { initial: string }) {
  const t = useT();
  const router = useRouter();
  const [q, setQ] = useState(initial);
  return (
    <form
      role="search"
      className="relative"
      onSubmit={(e) => {
        e.preventDefault();
        router.push(q.trim() ? `/search?q=${encodeURIComponent(q.trim())}` : "/search");
      }}
    >
      <Icon name="search" size={20} className="pointer-events-none absolute left-5 top-1/2 -translate-y-1/2 text-text-dim" />
      <input
        type="search"
        autoFocus
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t("Search titles, e.g. “Billionaire”, “Zanzibar”…")}
        aria-label={t("Search dramas")}
        className="h-14 w-full rounded-full border border-border bg-surface pl-14 pr-32 text-base placeholder:text-text-dim focus:border-primary focus:outline-none focus:ring-4 focus:ring-primary/15"
      />
      <button
        type="submit"
        className="absolute right-2 top-1/2 h-10 -translate-y-1/2 rounded-full bg-primary px-5 text-sm font-bold text-white transition hover:brightness-110"
      >
        {t("Search")}
      </button>
    </form>
  );
}
