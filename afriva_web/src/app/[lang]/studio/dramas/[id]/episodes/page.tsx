"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import {
  episodePlaybackUrl,
  episodeThumbUrl,
  episodeVideoStatus,
  isVideoPending,
  VideoStatusBadge,
  VideoUploadModal,
} from "@/components/portal/EpisodeVideo";
import { DataTable, PageHeader, Thumb } from "@/components/portal/Kit";
import { OrientationBadge } from "@/components/portal/Orientation";
import { BulkAddModal, EpisodeModal } from "@/components/studio/EpisodeModals";
import { Button } from "@/components/ui/Button";
import { ApiDownState, EmptyState, Pill } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal } from "@/components/ui/Modal";
import { useT } from "@/i18n/client";
import { fmt, plural } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { formatDuration, formatNumber } from "@/lib/format";
import { useApi, useList, usePolling } from "@/lib/hooks";
import type { Drama, Episode } from "@/lib/types";

export default function EpisodesManagerPage() {
  const { id } = useParams<{ id: string }>();
  const s = useT().studio;
  const t = s.episodes;
  const tc = useT().common;
  const tv = useT().portal.video;
  const drama = useApi<Drama>(`/studio/dramas/${id}`);
  const eps = useList<Episode>(`/studio/dramas/${id}/episodes`, { per_page: 500 });
  const episodes = useMemo(() => [...eps.items].sort((a, b) => a.number - b.number), [eps.items]);
  const maxNumber = episodes.length ? episodes[episodes.length - 1]!.number : 0;
  const freeEpisodes = drama.data?.free_episodes ?? 5;

  const [editing, setEditing] = useState<Episode | null>(null);
  const [adding, setAdding] = useState(false);
  const [bulk, setBulk] = useState(false);
  const [toDelete, setToDelete] = useState<Episode | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [moving, setMoving] = useState<number | null>(null);
  const [uploading, setUploading] = useState<Episode | null>(null);

  // Keep badges fresh while Bunny receives / encodes videos.
  usePolling(episodes.some(isVideoPending), eps.refresh);

  const base = `/studio/dramas/${id}/episodes`;

  /** Swap numbers of two episodes, going through a temporary number to respect unique(drama_id, number). */
  const swap = async (a: Episode, b: Episode) => {
    setMoving(a.id);
    const temp = maxNumber + 1000;
    try {
      await api.put(`${base}/${a.id}`, { number: temp });
      await api.put(`${base}/${b.id}`, { number: a.number });
      await api.put(`${base}/${a.id}`, { number: b.number });
      eps.setItems((list) =>
        list.map((e) => (e.id === a.id ? { ...e, number: b.number } : e.id === b.id ? { ...e, number: a.number } : e)),
      );
      toast.success(fmt(t.moved, { n: b.number }));
    } catch (e) {
      toast.error(errorMessage(e));
      eps.reload();
    } finally {
      setMoving(null);
    }
  };

  const doDelete = async () => {
    if (!toDelete) return;
    setDeleting(true);
    try {
      await api.del(`${base}/${toDelete.id}`);
      eps.setItems((list) => list.filter((e) => e.id !== toDelete.id));
      toast.success(fmt(t.deleted, { n: toDelete.number }));
      setToDelete(null);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setDeleting(false);
    }
  };

  const onSaved = () => {
    setAdding(false);
    setEditing(null);
    eps.reload();
  };

  return (
    <>
      <PageHeader
        back={
          <Link href={`/studio/dramas/${id}`} className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> {drama.data?.title ?? t.drama}
          </Link>
        }
        title={t.title}
        description={
          drama.data
            ? fmt(t.summary, {
                count: plural(episodes.length, tc.episodes),
                free: freeEpisodes,
                coins: drama.data.coins_per_episode,
              })
            : t.description
        }
        actions={
          <>
            <Button variant="secondary" size="sm" onClick={() => setBulk(true)}>
              <Icon name="layers" size={16} /> {t.bulkAdd}
            </Button>
            <Button size="sm" onClick={() => setAdding(true)}>
              <Icon name="plus" size={16} /> {t.add}
            </Button>
          </>
        }
      />

      {eps.error && !episodes.length ? (
        <ApiDownState action={<Button onClick={eps.reload}>{s.retry}</Button>} />
      ) : (
        <DataTable
          loading={eps.loading && !episodes.length}
          rows={episodes}
          rowKey={(e) => e.id}
          empty={
            <EmptyState
              className="border-0 bg-transparent"
              icon="film"
              title={t.none}
              description={t.noneHint}
              action={
                <div className="flex gap-2">
                  <Button variant="secondary" onClick={() => setBulk(true)}>
                    {t.bulkAdd}
                  </Button>
                  <Button onClick={() => setAdding(true)}>{t.add}</Button>
                </div>
              }
            />
          }
          columns={[
            {
              key: "order",
              header: s.cols.order,
              className: "w-24",
              render: (e) => {
                const idx = episodes.findIndex((x) => x.id === e.id);
                const prev = episodes[idx - 1];
                const next = episodes[idx + 1];
                return (
                  <div className="flex gap-1">
                    <button
                      disabled={!prev || moving !== null}
                      onClick={() => prev && swap(e, prev)}
                      className="grid h-7 w-7 place-items-center rounded-full border border-border text-text-muted transition hover:bg-surface-2 hover:text-text disabled:opacity-30"
                      aria-label={fmt(t.moveUp, { n: e.number })}
                    >
                      <Icon name="arrow-up" size={14} />
                    </button>
                    <button
                      disabled={!next || moving !== null}
                      onClick={() => next && swap(e, next)}
                      className="grid h-7 w-7 place-items-center rounded-full border border-border text-text-muted transition hover:bg-surface-2 hover:text-text disabled:opacity-30"
                      aria-label={fmt(t.moveDown, { n: e.number })}
                    >
                      <Icon name="arrow-down" size={14} />
                    </button>
                  </div>
                );
              },
            },
            {
              key: "ep",
              header: s.cols.episode,
              render: (e) => (
                <div className="flex items-center gap-3">
                  <span className="grid h-9 min-w-9 place-items-center rounded-lg bg-surface-2 px-2 text-sm font-extrabold">{e.number}</span>
                  {episodeThumbUrl(e) && <Thumb src={episodeThumbUrl(e)} alt="" className="w-8" />}
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{e.title || fmt(tc.episodeN, { n: e.number })}</p>
                    {e.video_url && <p className="max-w-[260px] truncate text-xs text-text-dim">{e.video_url}</p>}
                  </div>
                </div>
              ),
            },
            {
              key: "access",
              header: s.cols.access,
              render: (e) =>
                e.is_free ? (
                  <Pill tone="success">{t.free}</Pill>
                ) : (
                  <Pill tone="gold">
                    <Icon name="lock" size={11} /> {t.locked}
                  </Pill>
                ),
            },
            { key: "orientation", header: "", className: "w-8", render: (e) => <OrientationBadge value={e.orientation} /> },
            {
              key: "video",
              header: s.cols.video,
              render: (e) => <VideoStatusBadge episode={e} />,
            },
            { key: "duration", header: s.cols.duration, render: (e) => (e.duration_seconds ? formatDuration(e.duration_seconds) : "-") },
            { key: "views", header: s.cols.views, render: (e) => formatNumber(e.views ?? 0) },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (e) => (
                <div className="flex justify-end gap-1">
                  {episodeVideoStatus(e) === "failed" ? (
                    <Button size="sm" variant="danger" onClick={() => setUploading(e)}>
                      <Icon name="upload" size={14} /> {tv.reupload}
                    </Button>
                  ) : (
                    <button
                      onClick={() => setUploading(e)}
                      disabled={isVideoPending(e)}
                      className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text disabled:opacity-30"
                      aria-label={fmt(tv.uploadFor, { n: e.number })}
                      title={fmt(tv.uploadFor, { n: e.number })}
                    >
                      <Icon name="upload" size={16} />
                    </button>
                  )}
                  {episodePlaybackUrl(e) && episodeVideoStatus(e) === "ready" && (
                    <a
                      href={episodePlaybackUrl(e)!}
                      target="_blank"
                      rel="noreferrer"
                      className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                      aria-label={fmt(t.preview, { n: e.number })}
                    >
                      <Icon name="play" size={14} />
                    </a>
                  )}
                  <button
                    onClick={() => setEditing(e)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-surface-2 hover:text-text"
                    aria-label={fmt(t.edit, { n: e.number })}
                  >
                    <Icon name="edit" size={16} />
                  </button>
                  <button
                    onClick={() => setToDelete(e)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-muted transition hover:bg-danger/15 hover:text-danger"
                    aria-label={fmt(t.delete, { n: e.number })}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                </div>
              ),
            },
          ]}
        />
      )}

      <EpisodeModal
        open={adding || !!editing}
        onClose={() => {
          setAdding(false);
          setEditing(null);
          eps.refresh();
        }}
        dramaId={id}
        episode={editing}
        defaultNumber={maxNumber + 1}
        freeEpisodes={freeEpisodes}
        onSaved={onSaved}
      />
      <VideoUploadModal
        episode={uploading}
        scope="studio"
        dramaId={id}
        onClose={() => setUploading(null)}
        onUploaded={() => {
          setUploading(null);
          eps.refresh();
        }}
      />
      {bulk && (
        <BulkAddModal
          open
          onClose={() => setBulk(false)}
          dramaId={id}
          startNumber={maxNumber + 1}
          freeEpisodes={freeEpisodes}
          onDone={eps.reload}
        />
      )}
      <ConfirmModal
        open={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={doDelete}
        loading={deleting}
        danger
        title={fmt(t.deleteTitle, { n: toDelete?.number ?? "" })}
        confirmLabel={tc.actions.delete}
        message={t.deleteBody}
      />
    </>
  );
}
