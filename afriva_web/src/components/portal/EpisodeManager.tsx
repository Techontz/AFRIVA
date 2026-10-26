"use client";

import { useMemo, useState } from "react";
import { toast } from "sonner";
import { api, errorMessage } from "@/lib/api";
import { formatDuration, formatNumber } from "@/lib/format";
import { useT } from "@/lib/i18n";
import { isCreatorEditable } from "@/lib/portal";
import type { Episode, ManagedDrama } from "@/lib/types";
import { BulkAddModal, EpisodeModal } from "../studio/EpisodeModals";
import { Button } from "../ui/Button";
import { EmptyState, Pill } from "../ui/Feedback";
import { Icon } from "../ui/Icon";
import { ConfirmModal, Modal } from "../ui/Modal";
import { DataTable, Thumb } from "./Kit";
import { Notice, ReviewStatusPill, VideoPreview, VideoStatusPill } from "./ScopeKit";

/**
 * Episode list for one series, shared by Studio (creators) and Admin (`staff`).
 * Creators can change only draft / changes-requested episodes and reorder only while the series is editable.
 */
export function EpisodeManager({
  drama,
  dramaPath,
  staff,
  onChanged,
}: {
  drama: ManagedDrama;
  /** e.g. /studio/dramas/12 or /admin/dramas/12 */
  dramaPath: string;
  staff?: boolean;
  onChanged: () => void;
}) {
  const t = useT();
  const base = `${dramaPath}/episodes`;
  const [order, setOrder] = useState<Episode[] | null>(null);
  const episodes = useMemo(() => order ?? [...drama.episodes].sort((a, b) => a.number - b.number), [order, drama.episodes]);
  const maxNumber = episodes.length ? Math.max(...episodes.map((e) => e.number)) : 0;

  const seriesEditable = staff || isCreatorEditable(drama.review_status);
  const canAdd = staff || !["submitted", "in_review", "rejected"].includes(drama.review_status ?? "draft");
  const canEdit = (e: Episode) => staff || isCreatorEditable(e.review_status);

  const [editing, setEditing] = useState<Episode | null>(null);
  const [adding, setAdding] = useState(false);
  const [bulk, setBulk] = useState(false);
  const [preview, setPreview] = useState<Episode | null>(null);
  const [toDelete, setToDelete] = useState<Episode | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [saving, setSaving] = useState(false);

  const move = (idx: number, dir: -1 | 1) => {
    const list = [...episodes];
    const j = idx + dir;
    if (j < 0 || j >= list.length) return;
    [list[idx], list[j]] = [list[j]!, list[idx]!];
    setOrder(list.map((e, i) => ({ ...e, number: i + 1 })));
  };

  const saveOrder = async () => {
    if (!order) return;
    setSaving(true);
    try {
      await api.post(`${base}/reorder`, { episode_ids: order.map((e) => e.id) });
      toast.success(t("Episode order saved"));
      setOrder(null);
      onChanged();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setSaving(false);
    }
  };

  const doDelete = async () => {
    if (!toDelete) return;
    setDeleting(true);
    try {
      await api.del(`${base}/${toDelete.id}`);
      toast.success(t("Episode {n} deleted", { n: toDelete.number }));
      setToDelete(null);
      onChanged();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setDeleting(false);
    }
  };

  const onSaved = () => {
    setAdding(false);
    setEditing(null);
    onChanged();
  };

  return (
    <>
      {!seriesEditable && !staff && (
        <Notice tone="info" icon="lock" className="mb-4">
          {drama.review_status === "approved"
            ? t("This series is approved. Existing episodes are locked; you can still add new episodes and send them for review.")
            : drama.review_status === "rejected"
              ? t("This series was rejected and can no longer be changed.")
              : t("This series is under review, so episodes can't be changed now.")}
        </Notice>
      )}

      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-text-muted">
          {t("{count} episodes · first {free} free · {coins} coins to unlock each", {
            count: formatNumber(episodes.length),
            free: drama.free_episodes,
            coins: drama.coins_per_episode,
          })}
        </p>
        <div className="flex flex-wrap gap-2">
          {order && (
            <>
              <Button variant="ghost" size="sm" onClick={() => setOrder(null)}>
                {t("Cancel")}
              </Button>
              <Button size="sm" loading={saving} onClick={saveOrder}>
                <Icon name="check" size={16} /> {t("Save order")}
              </Button>
            </>
          )}
          {canAdd && !order && (
            <>
              <Button variant="secondary" size="sm" onClick={() => setBulk(true)}>
                <Icon name="layers" size={16} /> {t("Bulk add")}
              </Button>
              <Button size="sm" onClick={() => setAdding(true)}>
                <Icon name="plus" size={16} /> {t("Add episode")}
              </Button>
            </>
          )}
        </div>
      </div>

      <DataTable
        rows={episodes}
        rowKey={(e) => e.id}
        empty={
          <EmptyState
            className="border-0 bg-transparent"
            icon="film"
            title={t("No episodes yet")}
            description={t("Upload episode videos one by one, or add a whole season of video links at once.")}
            action={canAdd ? <Button onClick={() => setAdding(true)}>{t("Add episode")}</Button> : undefined}
          />
        }
        columns={[
          ...(seriesEditable
            ? [
                {
                  key: "order",
                  header: t("Order"),
                  className: "w-24",
                  render: (e: Episode) => {
                    const idx = episodes.findIndex((x) => x.id === e.id);
                    return (
                      <div className="flex gap-1">
                        <button
                          disabled={idx === 0}
                          onClick={() => move(idx, -1)}
                          className="grid h-7 w-7 place-items-center rounded-full border border-border text-text-muted transition hover:bg-surface-2 hover:text-text disabled:opacity-30"
                          aria-label={t("Move episode {n} up", { n: e.number })}
                        >
                          <Icon name="arrow-up" size={14} />
                        </button>
                        <button
                          disabled={idx === episodes.length - 1}
                          onClick={() => move(idx, 1)}
                          className="grid h-7 w-7 place-items-center rounded-full border border-border text-text-muted transition hover:bg-surface-2 hover:text-text disabled:opacity-30"
                          aria-label={t("Move episode {n} down", { n: e.number })}
                        >
                          <Icon name="arrow-down" size={14} />
                        </button>
                      </div>
                    );
                  },
                },
              ]
            : []),
          {
            key: "ep",
            header: t("Episode"),
            render: (e) => (
              <div className="flex items-center gap-3">
                <span className="grid h-9 min-w-9 place-items-center rounded-lg bg-surface-2 px-2 text-sm font-extrabold">{e.number}</span>
                {e.thumbnail_url && <Thumb src={e.thumbnail_url} alt="" className="w-8" />}
                <div className="min-w-0 max-w-[240px]">
                  <p className="truncate font-semibold">{e.title || t("Episode {n}", { n: e.number })}</p>
                  <p className="text-xs text-text-dim">
                    {e.is_free ? t("Free") : t("Locked")}
                    {e.subtitle_url ? ` · ${t("Subtitles")}` : ""}
                    {e.renditions?.length ? ` · ${e.renditions.join(" / ")}` : ""}
                  </p>
                </div>
              </div>
            ),
          },
          {
            key: "video",
            header: t("Video"),
            render: (e) => (e.video_url ? <VideoStatusPill status={e.video_status} error={e.video_error} /> : <Pill tone="danger">{t("No video")}</Pill>),
          },
          {
            key: "review",
            header: t("Review"),
            render: (e) => (
              <div className="flex max-w-[260px] flex-col items-start gap-1">
                <ReviewStatusPill status={e.review_status} />
                {e.playback_verified_at && (
                  <span className="inline-flex items-center gap-1 text-[11px] text-success">
                    <Icon name="check" size={11} /> {t("Playback checked")}
                  </span>
                )}
                {e.review_notes && ["changes_requested", "rejected"].includes(e.review_status ?? "") && (
                  <p className="line-clamp-2 text-xs text-text-muted" title={e.review_notes}>
                    {e.review_notes}
                  </p>
                )}
              </div>
            ),
          },
          { key: "duration", header: t("Duration"), render: (e) => (e.duration_seconds ? formatDuration(e.duration_seconds) : "—") },
          { key: "views", header: t("Views"), render: (e) => formatNumber(e.views ?? 0) },
          {
            key: "actions",
            header: "",
            className: "text-right",
            render: (e) => (
              <div className="flex justify-end gap-1">
                {!!e.sources?.length && (
                  <button
                    onClick={() => setPreview(e)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                    aria-label={t("Preview episode {n}", { n: e.number })}
                  >
                    <Icon name="play" size={14} />
                  </button>
                )}
                {canEdit(e) && !order && (
                  <>
                    <button
                      onClick={() => setEditing(e)}
                      className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                      aria-label={t("Edit episode {n}", { n: e.number })}
                    >
                      <Icon name="edit" size={16} />
                    </button>
                    <button
                      onClick={() => setToDelete(e)}
                      className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-danger/15 hover:text-danger"
                      aria-label={t("Delete episode {n}", { n: e.number })}
                    >
                      <Icon name="trash" size={16} />
                    </button>
                  </>
                )}
              </div>
            ),
          },
        ]}
      />

      <EpisodeModal
        open={adding || !!editing}
        onClose={() => {
          setAdding(false);
          setEditing(null);
        }}
        basePath={base}
        episode={editing}
        defaultNumber={maxNumber + 1}
        staff={staff}
        onSaved={onSaved}
      />
      {bulk && <BulkAddModal open onClose={() => setBulk(false)} basePath={base} startNumber={maxNumber + 1} onDone={onChanged} />}
      <Modal open={!!preview} onClose={() => setPreview(null)} title={preview ? t("Episode {n}", { n: preview.number }) : ""} size="sm">
        {preview && <VideoPreview sources={preview.sources ?? []} subtitleUrl={preview.subtitle_url} />}
      </Modal>
      <ConfirmModal
        open={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={doDelete}
        loading={deleting}
        danger
        title={t("Delete episode {n}?", { n: toDelete?.number })}
        confirmLabel={t("Delete")}
        message={t("The episode and its video will be removed. Viewers who unlocked it will lose access.")}
      />
    </>
  );
}
