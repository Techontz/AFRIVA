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
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { formatCompact, formatNumber } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import type { Drama } from "@/lib/types";

export default function StudioDramasPage() {
  const s = useT().studio;
  const t = s.dramas;
  const tc = useT().common;
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
      toast.success(fmt(next === "published" ? t.live : t.toDrafts, { title: d.title }));
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
      toast.success(t.deleted);
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
        title={t.title}
        description={t.description}
        actions={
          <Button href="/studio/dramas/new" size="sm">
            <Icon name="plus" size={16} /> {t.newDrama}
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
          placeholder={t.search}
        />
        <Select
          className="h-10 rounded-full py-0 sm:w-44"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          aria-label={t.filterStatus}
        >
          <option value="">{t.allStatuses}</option>
          <option value="published">{tc.status.published}</option>
          <option value="draft">{tc.status.draft}</option>
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <ApiDownState action={<Button onClick={reload}>{s.retry}</Button>} />
      ) : (
        <DataTable
          loading={loading}
          rows={items}
          rowKey={(d) => d.id}
          empty={
            <EmptyState
              className="border-0 bg-transparent"
              icon="film"
              title={q || status ? t.noMatch : t.none}
              description={t.emptyHint}
              action={<Button href="/studio/dramas/new">{t.create}</Button>}
            />
          }
          columns={[
            {
              key: "title",
              header: s.cols.drama,
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
            { key: "status", header: s.cols.status, render: (d) => <StatusPill status={d.status ?? "draft"} /> },
            { key: "eps", header: s.cols.episodes, render: (d) => formatNumber(d.total_episodes) },
            { key: "views", header: s.cols.views, render: (d) => formatCompact(d.views) },
            {
              key: "publish",
              header: s.cols.published,
              render: (d) => (
                <Toggle
                  size="sm"
                  label={fmt(t.publishX, { title: d.title })}
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
                    <Icon name="list" size={15} /> {t.episodes}
                  </Button>
                  <Link
                    href={`/studio/dramas/${d.id}`}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                    aria-label={fmt(t.editX, { title: d.title })}
                  >
                    <Icon name="edit" size={16} />
                  </Link>
                  <button
                    onClick={() => setToDelete(d)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-danger/15 hover:text-danger"
                    aria-label={fmt(t.deleteX, { title: d.title })}
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
        title={t.deleteTitle}
        confirmLabel={tc.actions.delete}
        message={fmt(t.deleteBody, { title: toDelete?.title ?? "" })}
      />
    </>
  );
}
