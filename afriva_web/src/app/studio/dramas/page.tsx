"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { DataTable, PageHeader, Pagination, SearchBox, Thumb, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { ApiDownState, EmptyState, Pill, StatusPill } from "@/components/ui/Feedback";
import { Select, Toggle } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatCompact, formatNumber } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import type { Drama } from "@/lib/types";

export default function StudioDramasPage() {
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const dq = useDebounced(q);
  const { items, meta, loading, error, reload, setItems } = useList<Drama>("/studio/dramas", {
    q: dq,
    search: dq,
    status,
    page,
    per_page: 20,
  });
  const [toDelete, setToDelete] = useState<Drama | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [busy, setBusy] = useState<number | null>(null);

  const togglePublish = async (d: Drama) => {
    const next = d.status === "published" ? "draft" : "published";
    setBusy(d.id);
    try {
      await api.put(`/studio/dramas/${d.id}`, { status: next });
      setItems((list) => list.map((x) => (x.id === d.id ? { ...x, status: next } : x)));
      toast.success(next === "published" ? `“${d.title}” is live` : `“${d.title}” moved to drafts`);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  const doDelete = async () => {
    if (!toDelete) return;
    setDeleting(true);
    try {
      await api.del(`/studio/dramas/${toDelete.id}`);
      setItems((list) => list.filter((x) => x.id !== toDelete.id));
      toast.success("Drama deleted");
      setToDelete(null);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setDeleting(false);
    }
  };

  return (
    <>
      <PageHeader
        title="My dramas"
        description="Create series, upload episodes and publish when you're ready."
        actions={
          <Button href="/studio/dramas/new" size="sm">
            <Icon name="plus" size={16} /> New drama
          </Button>
        }
      />
      <Toolbar>
        <SearchBox
          value={q}
          onChange={(v) => {
            setQ(v);
            setPage(1);
          }}
          placeholder="Search your dramas…"
        />
        <Select
          className="h-10 rounded-full py-0 sm:w-44"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          aria-label="Filter by status"
        >
          <option value="">All statuses</option>
          <option value="published">Published</option>
          <option value="draft">Draft</option>
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <ApiDownState action={<Button onClick={reload}>Retry</Button>} />
      ) : (
        <DataTable
          loading={loading}
          rows={items}
          rowKey={(d) => d.id}
          empty={
            <EmptyState
              className="border-0 bg-transparent"
              icon="film"
              title={q || status ? "No dramas match your filters" : "No dramas yet"}
              description="Start your first series — add a poster, synopsis and episodes."
              action={<Button href="/studio/dramas/new">Create a drama</Button>}
            />
          }
          columns={[
            {
              key: "title",
              header: "Drama",
              render: (d) => (
                <div className="flex items-center gap-3">
                  <Thumb src={d.poster_url} alt={d.title} />
                  <div className="min-w-0">
                    <Link href={`/studio/dramas/${d.id}`} className="block truncate font-semibold hover:text-primary">
                      {d.title}
                    </Link>
                    <div className="mt-1 flex flex-wrap gap-1">
                      {d.badge && <Pill tone="brand">{d.badge}</Pill>}
                      {d.categories?.slice(0, 2).map((c) => (
                        <Pill key={c.id}>{c.name}</Pill>
                      ))}
                    </div>
                  </div>
                </div>
              ),
            },
            { key: "status", header: "Status", render: (d) => <StatusPill status={d.status ?? "draft"} /> },
            { key: "eps", header: "Episodes", render: (d) => formatNumber(d.total_episodes) },
            { key: "views", header: "Views", render: (d) => formatCompact(d.views) },
            {
              key: "publish",
              header: "Published",
              render: (d) => (
                <Toggle
                  size="sm"
                  label={`Publish ${d.title}`}
                  checked={d.status === "published"}
                  disabled={busy === d.id}
                  onChange={() => togglePublish(d)}
                />
              ),
            },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (d) => (
                <div className="flex justify-end gap-1">
                  <Button href={`/studio/dramas/${d.id}/episodes`} variant="secondary" size="sm">
                    <Icon name="list" size={15} /> Episodes
                  </Button>
                  <Link
                    href={`/studio/dramas/${d.id}`}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                    aria-label={`Edit ${d.title}`}
                  >
                    <Icon name="edit" size={16} />
                  </Link>
                  <button
                    onClick={() => setToDelete(d)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-danger/15 hover:text-danger"
                    aria-label={`Delete ${d.title}`}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                </div>
              ),
            },
          ]}
        />
      )}
      <Pagination meta={meta} onPage={setPage} />

      <ConfirmModal
        open={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={doDelete}
        loading={deleting}
        danger
        title="Delete drama?"
        confirmLabel="Delete"
        message={
          <>
            “{toDelete?.title}” and all its episodes will be permanently removed. This can&apos;t be undone.
          </>
        }
      />
    </>
  );
}
