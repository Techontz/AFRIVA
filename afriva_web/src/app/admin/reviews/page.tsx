"use client";

import Link from "next/link";
import { useState } from "react";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Thumb, Toolbar } from "@/components/portal/Kit";
import { ReviewStatusPill } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/Feedback";
import { cn, formatDate } from "@/lib/format";
import { useApi, useDebounced } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import type { Drama } from "@/lib/types";

const TABS = [
  ["pending", "Waiting for review"],
  ["changes_requested", "Changes requested"],
  ["rejected", "Rejected"],
  ["approved", "Approved"],
] as const;

/** Ukaguzi (scope §04 "Kagua"): creator submissions waiting for a reviewer. */
export default function ReviewQueuePage() {
  const t = useT();
  const [tab, setTab] = useState<(typeof TABS)[number][0]>("pending");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { data, meta, loading, error, reload } = useApi<Drama[]>("/admin/reviews", { status: tab, q, page });
  const items = data ?? [];
  const counts = ((meta as unknown as { counts?: Record<string, number> })?.counts ?? {}) as Record<string, number>;

  return (
    <>
      <PageHeader title="Review" description="Check quality, rights and playback of creators' work before it can be published." />
      <div className="mb-4 flex flex-wrap gap-2" role="tablist">
        {TABS.map(([key, label]) => (
          <button
            key={key}
            role="tab"
            aria-selected={tab === key}
            onClick={() => {
              setTab(key);
              setPage(1);
            }}
            className={cn(
              "rounded-full px-4 py-2 text-sm font-semibold transition",
              tab === key ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:text-text",
            )}
          >
            {t(label)}
            {counts[key] !== undefined && <span className="ml-2 rounded-full bg-black/25 px-1.5 text-xs">{counts[key]}</span>}
          </button>
        ))}
      </div>
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder="Search titles…"
        />
      </Toolbar>
      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(d) => d.id}
            empty={<EmptyState className="border-0 bg-transparent" icon="check" title="Nothing waiting here" />}
            columns={[
              {
                key: "title",
                header: "Series",
                render: (d) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={d.poster_url} alt={d.title} />
                    <div className="min-w-0 max-w-[260px]">
                      <Link href={`/admin/reviews/${d.id}`} className="block truncate font-semibold hover:text-primary">
                        {d.title}
                      </Link>
                      <p className="truncate text-xs text-text-dim">{d.company?.name ?? "-"}</p>
                    </div>
                  </div>
                ),
              },
              { key: "status", header: "Series status", render: (d) => <ReviewStatusPill status={d.review_status} /> },
              {
                key: "eps",
                header: "Episodes to review",
                render: (d) => (
                  <span>
                    <b>{d.pending_episodes_count ?? 0}</b> <span className="text-text-dim">/ {d.episodes_count ?? d.total_episodes}</span>
                  </span>
                ),
              },
              { key: "sent", header: "Sent", render: (d) => formatDate(d.submitted_at, true) },
              {
                key: "go",
                header: "",
                className: "text-right",
                render: (d) => (
                  <Button size="sm" variant="secondary" href={`/admin/reviews/${d.id}`}>
                    {t("Open")}
                  </Button>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
    </>
  );
}
