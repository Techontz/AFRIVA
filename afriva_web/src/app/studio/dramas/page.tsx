"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { DataTable, PageHeader, Pagination, SearchBox, Thumb, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { ApiDownState, EmptyState, Pill } from "@/components/ui/Feedback";
import { LiveFlags, ReviewStatusPill } from "@/components/portal/ScopeKit";
import { Select } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatCompact, formatNumber } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { REVIEW_LABEL } from "@/lib/portal";
import type { Drama, ReviewStatus } from "@/lib/types";

export default function StudioDramasPage() {
  const t = useT();
  const [q, setQ] = useState("");
  const params = useSearchParams();
  const [review, setReview] = useState(params.get("review_status") ?? "");
  const [page, setPage] = useState(1);
  const dq = useDebounced(q);
  const { items, meta, loading, error, reload, setItems } = useList<Drama>("/studio/dramas", {
    q: dq,
    search: dq,
    review_status: review,
    page,
    per_page: 20,
  });
  const [toDelete, setToDelete] = useState<Drama | null>(null);
  const [deleting, setDeleting] = useState(false);
  const deletable = (d: Drama) => d.status !== "published" && ["draft", "changes_requested", "rejected"].includes(d.review_status ?? "draft");

  const doDelete = async () => {
    if (!toDelete) return;
    setDeleting(true);
    try {
      await api.del(`/studio/dramas/${toDelete.id}`);
      setItems((list) => list.filter((x) => x.id !== toDelete.id));
      toast.success(t("Series deleted"));
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
        title={t("My works")}
        description={t("Create series, upload episodes and send them to AFRIVA for review. Uploading does not mean publishing.")}
        actions={
          <Button href="/studio/dramas/new" size="sm">
            <Icon name="plus" size={16} /> {t("Submit your work")}
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
          placeholder={t("Search your dramas…")}
        />
        <Select
          className="h-10 rounded-full py-0 sm:w-44"
          value={review}
          onChange={(e) => {
            setReview(e.target.value);
            setPage(1);
          }}
          aria-label={t("Filter by status")}
        >
          <option value="">{t("All statuses")}</option>
          {(Object.keys(REVIEW_LABEL) as ReviewStatus[]).map((s) => (
            <option key={s} value={s}>
              {t(REVIEW_LABEL[s])}
            </option>
          ))}
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <ApiDownState action={<Button onClick={reload}>{t("Retry")}</Button>} />
      ) : (
        <DataTable
          loading={loading}
          rows={items}
          rowKey={(d) => d.id}
          empty={
            <EmptyState
              className="border-0 bg-transparent"
              icon="film"
              title={q || review ? t("No series match your filters") : t("No series yet")}
              description={t("Start your first series: add a poster, synopsis and episodes.")}
              action={<Button href="/studio/dramas/new">{t("Submit your work")}</Button>}
            />
          }
          columns={[
            {
              key: "title",
              header: t("Series"),
              render: (d) => (
                <div className="flex items-center gap-3">
                  <Thumb src={d.poster_url} alt={d.title} />
                  <div className="min-w-0">
                    <Link href={`/studio/dramas/${d.id}`} className="block truncate font-semibold hover:text-primary">
                      {d.title}
                    </Link>
                    <div className="mt-1 flex flex-wrap gap-1">
                      {d.categories?.slice(0, 2).map((c) => (
                        <Pill key={c.id}>{c.name}</Pill>
                      ))}
                    </div>
                  </div>
                </div>
              ),
            },
            { key: "review", header: t("Review"), render: (d) => <ReviewStatusPill status={d.review_status} /> },
            { key: "live", header: t("On AFRIVA"), render: (d) => <LiveFlags drama={d} /> },
            {
              key: "eps",
              header: t("Episodes"),
              render: (d) => (
                <span title={t("{live} live of {all}", { live: d.total_episodes, all: d.episodes_count ?? d.total_episodes })}>
                  {formatNumber(d.total_episodes)} / {formatNumber(d.episodes_count ?? d.total_episodes)}
                </span>
              ),
            },
            { key: "views", header: t("Views"), render: (d) => formatCompact(d.views) },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (d) => (
                <div className="flex justify-end gap-1">
                  <Button href={`/studio/dramas/${d.id}/episodes`} variant="secondary" size="sm">
                    <Icon name="list" size={15} /> {t("Episodes")}
                  </Button>
                  <Link
                    href={`/studio/dramas/${d.id}`}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                    aria-label={t("Edit {title}", { title: d.title })}
                  >
                    <Icon name="edit" size={16} />
                  </Link>
                  <Link
                    href={`/studio/dramas/${d.id}/analytics`}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                    aria-label={t("Analytics for {title}", { title: d.title })}
                  >
                    <Icon name="chart" size={16} />
                  </Link>
                  {deletable(d) && (
                  <button
                    onClick={() => setToDelete(d)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-danger/15 hover:text-danger"
                    aria-label={t("Delete {title}", { title: d.title })}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                  )}
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
        title={t("Delete series?")}
        confirmLabel={t("Delete")}
        message={t("“{title}” and all its episodes will be permanently removed. This can't be undone.", { title: toDelete?.title })}
      />
    </>
  );
}
