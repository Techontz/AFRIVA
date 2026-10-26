"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Thumb, Toolbar } from "@/components/portal/Kit";
import { Notice, ReviewStatusPill, VideoPreview, VideoStatusPill } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { Pill } from "@/components/ui/Feedback";
import { Checkbox, Select } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatDate, formatDuration } from "@/lib/format";
import { useApi, useDebounced } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { bytes, REVIEW_LABEL, VIDEO_STATUS_LABEL, type AdminVideo } from "@/lib/portal";
import type { PageMeta, ReviewStatus, VideoStatus } from "@/lib/types";

/** Video Library (scope §05 "Video tools"): processing state, renditions, playback check, reprocess. */
export default function VideoLibraryPage() {
  const t = useT();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [review, setReview] = useState("");
  const [unverified, setUnverified] = useState(false);
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { data, meta, loading, error, reload, mutate } = useApi<AdminVideo[]>("/admin/videos", {
    q,
    video_status: status,
    review_status: review,
    unverified: unverified ? 1 : undefined,
    page,
  });
  const items = data ?? [];
  const extra = (meta ?? {}) as PageMeta & { counts?: Record<string, number>; transcoding_enabled?: boolean };
  const [preview, setPreview] = useState<AdminVideo | null>(null);
  const [busy, setBusy] = useState<number | null>(null);

  const reprocess = async (v: AdminVideo) => {
    setBusy(v.id);
    try {
      const res = await api.post<{ video_status: VideoStatus }>(`/admin/videos/${v.id}/reprocess`);
      mutate((list) => (list ?? []).map((x) => (x.id === v.id ? { ...x, video_status: res.video_status, video_error: null } : x)));
      toast.success(t("Processing started"));
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <PageHeader title="Video Library" description="Every episode video, its processing state and quality levels." />
      {extra.transcoding_enabled === false && (
        <Notice tone="warning" className="mb-4" title="Transcoding is switched off">
          {t("Uploaded files are played as uploaded (one quality). Set MEDIA_TRANSCODE=true with ffmpeg installed to encode 480p/720p/1080p.")}
        </Notice>
      )}
      <div className="mb-4 flex flex-wrap gap-2">
        {(Object.keys(VIDEO_STATUS_LABEL) as VideoStatus[]).map((s) => (
          <button
            key={s}
            onClick={() => (setStatus(status === s ? "" : s), setPage(1))}
            className={`flex items-center gap-2 rounded-full py-1 pl-1 pr-3 text-sm ${status === s ? "bg-primary/20" : "bg-surface-2"}`}
          >
            <VideoStatusPill status={s} />
            <b>{extra.counts?.[s] ?? 0}</b>
          </button>
        ))}
      </div>
      <Toolbar>
        <SearchBox value={search} onChange={(v) => (setSearch(v), setPage(1))} placeholder="Search series…" />
        <Select className="sm:w-48" value={review} onChange={(e) => (setReview(e.target.value), setPage(1))} aria-label={t("Filter by review status")}>
          <option value="">{t("All review statuses")}</option>
          {(Object.keys(REVIEW_LABEL) as ReviewStatus[]).map((s) => (
            <option key={s} value={s}>
              {t(REVIEW_LABEL[s])}
            </option>
          ))}
        </Select>
        <Checkbox checked={unverified} onChange={(v) => (setUnverified(v), setPage(1))} label={t("Playback not checked")} />
      </Toolbar>
      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(v) => v.id}
            columns={[
              {
                key: "ep",
                header: "Episode",
                render: (v) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={v.thumbnail_url ?? v.drama?.poster_url} alt="" />
                    <div className="min-w-0 max-w-[240px]">
                      <Link href={v.drama ? `/admin/dramas/${v.drama.id}/episodes` : "#"} className="block truncate font-semibold hover:text-primary">
                        {v.drama?.title ?? "-"}
                      </Link>
                      <p className="truncate text-xs text-text-dim">
                        {t("Episode {n}", { n: v.number })} · {v.drama?.company ?? ""}
                      </p>
                    </div>
                  </div>
                ),
              },
              { key: "status", header: "Processing", render: (v) => <VideoStatusPill status={v.video_status} error={v.video_error} /> },
              {
                key: "q",
                header: "Quality",
                render: (v) =>
                  v.renditions.length ? (
                    <div className="flex flex-wrap gap-1">
                      {v.renditions.map((r) => (
                        <Pill key={r}>{r}</Pill>
                      ))}
                    </div>
                  ) : (
                    <span className="text-xs text-text-dim">{v.is_uploaded ? t("Original") : t("External link")}</span>
                  ),
              },
              { key: "size", header: "Size", render: (v) => bytes(v.source_size) },
              { key: "dur", header: "Duration", render: (v) => (v.duration_seconds ? formatDuration(v.duration_seconds) : "—") },
              {
                key: "review",
                header: "Review",
                render: (v) => (
                  <div className="flex flex-col items-start gap-1">
                    <ReviewStatusPill status={v.review_status} />
                    <span className="text-[11px] text-text-dim">
                      {v.playback_verified_at ? t("Checked {date}", { date: formatDate(v.playback_verified_at) }) : t("Playback not checked")}
                    </span>
                  </div>
                ),
              },
              { key: "sub", header: "Subtitles", render: (v) => (v.subtitle_url ? <Icon name="check" size={16} className="text-success" /> : "—") },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (v) => (
                  <div className="flex justify-end gap-1">
                    {v.sources.length > 0 && (
                      <Button size="sm" variant="ghost" onClick={() => setPreview(v)}>
                        <Icon name="play" size={14} /> {t("Play")}
                      </Button>
                    )}
                    {v.is_uploaded && (
                      <Button size="sm" variant="ghost" loading={busy === v.id} disabled={v.video_status === "processing"} onClick={() => reprocess(v)}>
                        <Icon name="refresh" size={14} /> {t("Reprocess")}
                      </Button>
                    )}
                  </div>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
      <Modal open={!!preview} onClose={() => setPreview(null)} title={preview ? `${preview.drama?.title ?? ""} · ${t("Episode {n}", { n: preview.number })}` : ""} size="sm">
        {preview && <VideoPreview sources={preview.sources} subtitleUrl={preview.subtitle_url} />}
      </Modal>
    </>
  );
}
