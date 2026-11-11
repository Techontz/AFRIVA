"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { useT } from "@/i18n/client";
import { Icon } from "../ui/Icon";

export function SearchForm({ initial }: { initial: string }) {
  const router = useRouter();
  const [q, setQ] = useState(initial);
  const t = useT().site.search;
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
        placeholder={t.placeholder}
        aria-label={t.label}
        className="h-14 w-full rounded-full bg-text/10 pl-14 pr-28 text-base placeholder:text-text-dim focus:bg-text/15 focus:outline-none focus:ring-2 focus:ring-text/20"
      />
      <button
        type="submit"
        className="absolute right-2 top-1/2 h-10 -translate-y-1/2 rounded-full bg-primary px-5 text-sm font-bold text-white transition hover:brightness-110"
      >
        {t.submit}
      </button>
    </form>
  );
}
