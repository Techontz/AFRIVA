"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError, str } from "@/components/admin/helpers";
import { DataTable, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill } from "@/components/ui/Feedback";
import { Field, Input, Toggle } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatCompact, formatDuration } from "@/lib/format";
import { useApi, useList } from "@/lib/hooks";
import type { Drama, Episode } from "@/lib/types";

export default function AdminEpisodesPage() {
  const { id } = useParams<{ id: string }>();
  const drama = useApi<Drama>(`/admin/dramas/${id}`);
  const { items, loading, error, reload, setItems } = useList<Episode>(`/admin/dramas/${id}/episodes`, { per_page: 500 });
  const episodes = [...items].sort((a, b) => a.number - b.number);
  const base = `/admin/dramas/${id}/episodes`;

  const [editing, setEditing] = useState<Episode | null>(null);
  const [form, setForm] = useState({ title: "", video_url: "", is_free: false });
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Episode | null>(null);
  const [busy, setBusy] = useState(false);

  const openEdit = (e: Episode) => {
    setEditing(e);
    setForm({ title: str(e.title), video_url: str(e.video_url), is_free: e.is_free });
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

  const save = async (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!editing) return;
    setSaving(true);
    try {
      await api.put(`${base}/${editing.id}`, form);
      setItems((list) => list.map((x) => (x.id === editing.id ? { ...x, ...form } : x)));
      toast.success(`Episode ${editing.number} updated`);
      setEditing(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const remove = async () => {
    if (!deleting) return;
    setBusy(true);
    try {
      await api.del(`${base}/${deleting.id}`);
      setItems((list) => list.filter((x) => x.id !== deleting.id));
      toast.success(`Episode ${deleting.number} deleted`);
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
            <Icon name="chevron-left" size={14} /> Dramas
          </Link>
        }
        title={drama.data?.title ? `${drama.data.title} · Episodes` : "Episodes"}
        description={
          drama.data
            ? `${drama.data.company?.name ?? ""} · ${episodes.length} episodes · first ${drama.data.free_episodes} free · ${drama.data.coins_per_episode} coins each`
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
              header: "Title",
              render: (e) => (
                <div className="min-w-0 max-w-[280px]">
                  <p className="truncate font-semibold">{e.title || `Episode ${e.number}`}</p>
                  {e.video_url && <p className="truncate text-[11px] text-text-dim">{e.video_url}</p>}
                </div>
              ),
            },
            { key: "dur", header: "Duration", render: (e) => formatDuration(e.duration_seconds) },
            { key: "views", header: "Views", render: (e) => formatCompact(e.views ?? 0) },
            {
              key: "free",
              header: "Free",
              render: (e) => (
                <div className="flex items-center gap-2">
                  <Toggle size="sm" label="Free" checked={e.is_free} onChange={(v) => toggleFree(e, v)} />
                  {!e.is_free && <Pill tone="gold">Locked</Pill>}
                </div>
              ),
            },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (e) => (
                <div className="flex justify-end gap-1">
                  <Button size="sm" variant="ghost" onClick={() => openEdit(e)}>
                    Edit
                  </Button>
                  <button
                    onClick={() => setDeleting(e)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                    aria-label={`Delete episode ${e.number}`}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                </div>
              ),
            },
          ]}
        />
      )}

      <Modal open={!!editing} onClose={() => setEditing(null)} title={`Edit episode ${editing?.number ?? ""}`}>
        <form onSubmit={save} className="flex flex-col gap-4">
          <Field label="Title">
            <Input value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
          </Field>
          <Field label="Video URL">
            <Input type="url" value={form.video_url} onChange={(e) => setForm((f) => ({ ...f, video_url: e.target.value }))} />
          </Field>
          <label className="flex items-center justify-between rounded-xl border border-border px-4 py-3 text-sm">
            <span>
              <span className="font-semibold">Free episode</span>
              <span className="block text-xs text-text-dim">Overrides the drama&apos;s free-episode count</span>
            </span>
            <Toggle checked={form.is_free} onChange={(v) => setForm((f) => ({ ...f, is_free: v }))} label="Free episode" />
          </label>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setEditing(null)}>
              Cancel
            </Button>
            <Button type="submit" loading={saving}>
              Save
            </Button>
          </div>
        </form>
      </Modal>

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title={`Delete episode ${deleting?.number ?? ""}?`}
        message="Viewers who unlocked it will lose access. This cannot be undone."
        confirmLabel="Delete"
      />
    </>
  );
}
