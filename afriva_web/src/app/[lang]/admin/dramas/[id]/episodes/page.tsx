"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError, str } from "@/components/admin/helpers";
import {
  EpisodeVideoInput,
  UploadProgress,
  VideoStatusBadge,
  VideoUploadModal,
  episodePlaybackUrl,
  episodeVideoStatus,
  isVideoPending,
  type EpisodeVideoValue,
} from "@/components/portal/EpisodeVideo";
import { DataTable, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill } from "@/components/ui/Feedback";
import { Field, Input, Toggle } from "@/components/ui/Form";
import { OrientationBadge, OrientationPicker } from "@/components/portal/Orientation";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { useT } from "@/i18n/client";
import { fmt, plural } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { formatCompact, formatDuration } from "@/lib/format";
import { useApi, useList, usePolling } from "@/lib/hooks";
import type { Drama, Episode, EpisodeOrientation } from "@/lib/types";
import { useEpisodeVideoUpload } from "@/lib/videoUpload";

export default function AdminEpisodesPage() {
  const { id } = useParams<{ id: string }>();
  const { admin, common, portal } = useT();
  const tv = portal.video;
  const tr = admin.episodes;
  const col = admin.cols;
  const epTitle = (n: number | string) => fmt(common.episodeN, { n });
  const drama = useApi<Drama>(`/admin/dramas/${id}`);
  const { items, loading, error, reload, refresh, setItems } = useList<Episode>(`/admin/dramas/${id}/episodes`, { per_page: 500 });
  const episodes = [...items].sort((a, b) => a.number - b.number);
  const base = `/admin/dramas/${id}/episodes`;

  const [editing, setEditing] = useState<Episode | null>(null);
  const [form, setForm] = useState<{ title: string; video: EpisodeVideoValue; is_free: boolean; orientation: EpisodeOrientation }>({
    title: "",
    video: { mode: "upload", url: "", file: null },
    is_free: false,
    orientation: "portrait",
  });
  const [uploadingRow, setUploadingRow] = useState<Episode | null>(null);
  const up = useEpisodeVideoUpload();

  // Keep badges fresh while Bunny receives / encodes videos.
  usePolling(items.some(isVideoPending), refresh);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Episode | null>(null);
  const [busy, setBusy] = useState(false);

  const openEdit = (e: Episode) => {
    setEditing(e);
    const url = e.bunny_video_id ? "" : str(e.video_url);
    up.reset();
    setForm({ title: str(e.title), video: { mode: url ? "url" : "upload", url, file: null }, is_free: e.is_free, orientation: e.orientation ?? "portrait" });
  };

  const toggleFree = async (e: Episode, is_free: boolean) => {
    setItems((list) => list.map((x) => (x.id === e.id ? { ...x, is_free } : x)));
    try {
      await api.put(`${base}/${e.id}`, { is_free });
    } catch (err) {
      setItems((list) => list.map((x) => (x.id === e.id ? { ...x, is_free: e.is_free } : x)));
      toast.error(errorMessage(err));
    }
  };

  const closeEdit = () => {
    if (up.active) return;
    if (up.state.phase !== "idle") refresh();
    up.reset();
    setEditing(null);
  };

  const save = async (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!editing) return;
    const { mode, url, file } = form.video;
    const originalUrl = editing.bunny_video_id ? "" : str(editing.video_url);
    const body: Record<string, unknown> = { title: form.title, is_free: form.is_free, orientation: form.orientation };
    // Only send video_url when it was edited, so a Bunny-hosted video is never clobbered.
    if (mode === "url" && url !== originalUrl) body.video_url = url || null;
    setSaving(true);
    try {
      await api.put(`${base}/${editing.id}`, body);
      setItems((list) =>
        list.map((x) =>
          x.id === editing.id
            ? { ...x, title: form.title, is_free: form.is_free, orientation: form.orientation, ...("video_url" in body ? { video_url: url || null } : {}) }
            : x,
        ),
      );
      toast.success(fmt(tr.updated, { name: epTitle(editing.number) }));
    } catch (err) {
      toast.error(errorMessage(err));
      setSaving(false);
      return;
    }
    setSaving(false);
    if (mode === "upload" && file) {
      const done = await up.start("admin", id, editing.id, file);
      if (!done) return; // progress panel shows the error / cancel state
      toast.success(tv.done);
      up.reset();
      refresh();
    }
    setEditing(null);
  };

  const remove = async () => {
    if (!deleting) return;
    setBusy(true);
    try {
      await api.del(`${base}/${deleting.id}`);
      setItems((list) => list.filter((x) => x.id !== deleting.id));
      toast.success(fmt(tr.deleted, { name: epTitle(deleting.number) }));
      setDeleting(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader
        back={
          <Link href="/admin/dramas" className="inline-flex items-center gap-1 text-xs font-semibold text-text-muted hover:text-text">
            <Icon name="chevron-left" size={14} /> {admin.nav.dramas}
          </Link>
        }
        title={drama.data?.title ? `${drama.data.title} · ${col.episodes}` : col.episodes}
        description={
          drama.data
            ? `${drama.data.company?.name ?? ""} · ${plural(episodes.length, common.episodes)} · ${fmt(tr.summary, { free: drama.data.free_episodes ?? 0, coins: drama.data.coins_per_episode ?? 0 })}`
            : undefined
        }
      />

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <DataTable
          loading={loading}
          rows={episodes}
          rowKey={(e) => e.id}
          columns={[
            { key: "n", header: "#", className: "w-14", render: (e) => <span className="font-bold">{e.number}</span> },
            {
              key: "title",
              header: col.title,
              render: (e) => (
                <div className="min-w-0 max-w-[280px]">
                  <p className="truncate font-semibold">{e.title || epTitle(e.number)}</p>
                  {e.video_url && <p className="truncate text-[11px] text-text-dim">{e.video_url}</p>}
                </div>
              ),
            },
            { key: "orientation", header: "", className: "w-8", render: (e) => <OrientationBadge value={e.orientation} /> },
            { key: "video", header: col.video, render: (e) => <VideoStatusBadge episode={e} /> },
            { key: "dur", header: col.duration, render: (e) => formatDuration(e.duration_seconds) },
            { key: "views", header: col.views, render: (e) => formatCompact(e.views ?? 0) },
            {
              key: "free",
              header: tr.free,
              render: (e) => (
                <div className="flex items-center gap-2">
                  <Toggle size="sm" label={tr.free} checked={e.is_free} onChange={(v) => toggleFree(e, v)} />
                  {!e.is_free && <Pill tone="gold">{tr.locked}</Pill>}
                </div>
              ),
            },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (e) => (
                <div className="flex justify-end gap-1">
                  {episodeVideoStatus(e) === "failed" && (
                    <Button size="sm" variant="danger" onClick={() => setUploadingRow(e)}>
                      <Icon name="upload" size={14} /> {tv.reupload}
                    </Button>
                  )}
                  {episodePlaybackUrl(e) && episodeVideoStatus(e) === "ready" && (
                    <a
                      href={episodePlaybackUrl(e)!}
                      target="_blank"
                      rel="noreferrer"
                      className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-surface-2 hover:text-text"
                      aria-label={fmt(tr.preview, { name: epTitle(e.number) })}
                    >
                      <Icon name="play" size={14} />
                    </a>
                  )}
                  <Button size="sm" variant="ghost" onClick={() => openEdit(e)}>
                    {common.actions.edit}
                  </Button>
                  <button
                    onClick={() => setDeleting(e)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                    aria-label={fmt(admin.deleteNamed, { name: epTitle(e.number) })}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                </div>
              ),
            },
          ]}
        />
      )}

      <Modal open={!!editing} onClose={closeEdit} title={fmt(admin.editNamed, { name: epTitle(editing?.number ?? "") })}>
        {up.state.phase !== "idle" && editing && form.video.file ? (
          <div className="flex flex-col gap-4">
            <UploadProgress
              state={up.state}
              onCancel={up.cancel}
              onResume={up.resume}
              onRetry={() => void up.start("admin", id, editing.id, form.video.file!)}
            />
            <div className="flex justify-end">
              <Button type="button" variant="ghost" onClick={closeEdit} disabled={up.active}>
                {common.actions.close}
              </Button>
            </div>
          </div>
        ) : (
          <form onSubmit={save} className="flex flex-col gap-4">
            <Field label={admin.fields.title}>
              <Input value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
            </Field>
            <OrientationPicker value={form.orientation} onChange={(orientation) => setForm((f) => ({ ...f, orientation }))} disabled={saving} />
            <EpisodeVideoInput
              label={tr.video}
              value={form.video}
              onChange={(video) => setForm((f) => ({ ...f, video }))}
              episode={editing}
              disabled={saving}
            />
            <label className="flex items-center justify-between rounded-xl border border-border px-4 py-3 text-sm">
              <span>
                <span className="font-semibold">{tr.freeEpisode}</span>
                <span className="block text-xs text-text-dim">{tr.freeHint}</span>
              </span>
              <Toggle checked={form.is_free} onChange={(v) => setForm((f) => ({ ...f, is_free: v }))} label={tr.freeEpisode} />
            </label>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="ghost" onClick={closeEdit}>
                {common.actions.cancel}
              </Button>
              <Button type="submit" loading={saving}>
                {common.actions.save}
              </Button>
            </div>
          </form>
        )}
      </Modal>

      <VideoUploadModal
        episode={uploadingRow}
        scope="admin"
        dramaId={id}
        onClose={() => setUploadingRow(null)}
        onUploaded={() => {
          setUploadingRow(null);
          refresh();
        }}
      />

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title={fmt(tr.deleteTitle, { name: epTitle(deleting?.number ?? "") })}
        message={tr.deleteBody}
        confirmLabel={common.actions.delete}
      />
    </>
  );
}
