"use client";

import { useState, type FormEvent } from "react";
import { toast } from "sonner";
import { appendMedia, MediaInput, type MediaValue } from "@/components/portal/MediaInput";
import { Button } from "@/components/ui/Button";
import { Checkbox, Field, Input, Select, Textarea } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { api, ApiError, errorMessage } from "@/lib/api";
import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { Episode } from "@/lib/types";

export const SAMPLE_VIDEOS = [
  "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
  "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
  "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
];

interface EpisodeFormState {
  number: string;
  title: string;
  video: MediaValue;
  thumbnail: MediaValue;
  subtitle: File | null;
  duration_seconds: string;
  /** Staff only: null = follow the series' free-episode count. */
  is_free: "" | "1" | "0";
}

/**
 * Episode form shared by the Studio (creators) and Admin (staff, `staff` = true).
 * `basePath` is the episodes collection, e.g. /studio/dramas/12/episodes.
 */
function EpisodeForm({
  basePath,
  episode,
  defaultNumber,
  staff,
  onSaved,
  onCancel,
}: {
  basePath: string;
  episode?: Episode | null;
  defaultNumber: number;
  staff?: boolean;
  onSaved: (e: Episode | null) => void;
  onCancel: () => void;
}) {
  const t = useT();
  const [f, setF] = useState<EpisodeFormState>(() => ({
    number: String(episode?.number ?? defaultNumber),
    title: episode?.title ?? "",
    video: { url: episode?.video_url && !episode.video_url.includes("/media/videos/") ? episode.video_url : "", file: null },
    thumbnail: { url: episode?.thumbnail_url ?? "", file: null },
    subtitle: null,
    duration_seconds: episode?.duration_seconds ? String(episode.duration_seconds) : "",
    is_free: episode?.is_free_override === true ? "1" : episode?.is_free_override === false ? "0" : "",
  }));
  const [saving, setSaving] = useState(false);
  const [progress, setProgress] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  const set = <K extends keyof EpisodeFormState>(k: K, v: EpisodeFormState[K]) => setF((s) => ({ ...s, [k]: v }));
  const err = (k: string) => errors[k]?.[0] ?? null;
  const hasUploadedVideo = !!episode?.video_url?.includes("/media/videos/");

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!episode && !f.video.url && !f.video.file) {
      setErrors({ video: [t("Add a video URL or upload a file")] });
      return;
    }
    setSaving(true);
    setErrors({});
    const scalar: Record<string, string | number | boolean | null> = {
      number: Number(f.number),
      title: f.title || null,
      duration_seconds: f.duration_seconds ? Number(f.duration_seconds) : null,
    };
    if (staff) scalar.is_free = f.is_free === "" ? null : f.is_free === "1";
    const fd = new FormData();
    for (const [k, v] of Object.entries(scalar)) {
      if (v === null) {
        if (k === "is_free") fd.append(k, "");
        continue;
      }
      fd.append(k, typeof v === "boolean" ? (v ? "1" : "0") : String(v));
    }
    if (f.video.file) {
      fd.append("video", f.video.file);
      setProgress(t("Uploading {size} MB…", { size: (f.video.file.size / 1024 / 1024).toFixed(1) }));
    } else if (f.video.url) {
      fd.append("video_url", f.video.url);
    }
    appendMedia(fd, "thumbnail", f.thumbnail);
    if (f.subtitle) fd.append("subtitle", f.subtitle);
    try {
      const saved = episode ? await api.put<Episode>(`${basePath}/${episode.id}`, fd) : await api.post<Episode>(basePath, fd);
      toast.success(episode ? t("Episode updated") : t("Episode {n} added", { n: scalar.number as number }));
      onSaved(saved ?? null);
    } catch (e) {
      if (e instanceof ApiError && e.errors) setErrors(e.errors);
      toast.error(errorMessage(e));
    } finally {
      setSaving(false);
      setProgress(null);
    }
  };

  return (
    <form onSubmit={submit} className="grid gap-4">
      <div className="grid grid-cols-[110px_1fr] gap-3">
        <Field label={t("Number")} htmlFor="ep-number" error={err("number")}>
          <Input id="ep-number" type="number" min={1} required value={f.number} onChange={(e) => set("number", e.target.value)} />
        </Field>
        <Field label={t("Title (optional)")} htmlFor="ep-title" error={err("title")}>
          <Input id="ep-title" value={f.title} onChange={(e) => set("title", e.target.value)} placeholder={t("Episode {n}", { n: f.number })} />
        </Field>
      </div>
      <MediaInput
        label={hasUploadedVideo ? t("Replace video (optional)") : t("Video")}
        kind="video"
        accept="video/*"
        value={f.video}
        onChange={(v) => set("video", v)}
      />
      {(err("video") || err("video_url")) && <p className="-mt-2 text-xs text-danger">{err("video") || err("video_url")}</p>}
      {episode && f.video.file && (
        <p className="-mt-2 text-xs text-text-muted">{t("A new video must be checked again before it can be approved.")}</p>
      )}
      <MediaInput label={t("Thumbnail (optional)")} value={f.thumbnail} onChange={(v) => set("thumbnail", v)} aspect="aspect-[9/16]" />
      <Field
        label={t("Subtitles (.vtt or .srt, optional)")}
        hint={episode?.subtitle_url ? t("Current file is kept unless you choose a new one.") : undefined}
        error={err("subtitle")}
      >
        <input
          type="file"
          accept=".vtt,.srt,text/vtt"
          onChange={(e) => set("subtitle", e.target.files?.[0] ?? null)}
          className="text-sm text-text-muted file:mr-3 file:rounded-full file:border-0 file:bg-surface-2 file:px-3 file:py-1.5 file:text-xs file:font-semibold file:text-text"
        />
      </Field>
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label={t("Duration (sec)")} htmlFor="ep-dur" hint={t("Filled in automatically after processing")} error={err("duration_seconds")}>
          <Input id="ep-dur" type="number" min={0} value={f.duration_seconds} onChange={(e) => set("duration_seconds", e.target.value)} placeholder="90" />
        </Field>
        {staff && (
          <Field label={t("Free / locked")} htmlFor="ep-free" hint={t("Overrides the series' free-episode count")}>
            <Select id="ep-free" value={f.is_free} onChange={(e) => set("is_free", e.target.value as EpisodeFormState["is_free"])}>
              <option value="">{t("Follow the series rule")}</option>
              <option value="1">{t("Always free")}</option>
              <option value="0">{t("Always locked")}</option>
            </Select>
          </Field>
        )}
      </div>
      {progress && <p className="text-xs text-text-muted">{progress}</p>}
      <div className="flex justify-end gap-2 pt-1">
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t("Cancel")}
        </Button>
        <Button type="submit" loading={saving}>
          {episode ? t("Save episode") : t("Add episode")}
        </Button>
      </div>
    </form>
  );
}

export function EpisodeModal({
  open,
  onClose,
  ...props
}: {
  open: boolean;
  onClose: () => void;
  basePath: string;
  episode?: Episode | null;
  defaultNumber: number;
  staff?: boolean;
  onSaved: (e: Episode | null) => void;
}) {
  const t = useT();
  return (
    <Modal open={open} onClose={onClose} title={props.episode ? t("Edit episode {n}", { n: props.episode.number }) : t("Add episode")}>
      {open && <EpisodeForm key={props.episode?.id ?? "new"} {...props} onCancel={onClose} />}
    </Modal>
  );
}

type BulkMode = "range" | "list";

export function BulkAddModal({
  open,
  onClose,
  basePath,
  startNumber,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  basePath: string;
  startNumber: number;
  onDone: () => void;
}) {
  const t = useT();
  const [mode, setMode] = useState<BulkMode>("range");
  const [start, setStart] = useState(String(startNumber));
  const [count, setCount] = useState("10");
  const [pattern, setPattern] = useState("");
  const [rotate, setRotate] = useState(true);
  const [urls, setUrls] = useState("");
  const [duration, setDuration] = useState("");
  const [running, setRunning] = useState(false);
  const [done, setDone] = useState(0);
  const [failed, setFailed] = useState<string[]>([]);

  const planned = (() => {
    const s = Math.max(1, Number(start) || 1);
    if (mode === "list") {
      return urls
        .split(/\r?\n/)
        .map((u) => u.trim())
        .filter(Boolean)
        .map((u, i) => ({ number: s + i, video_url: u }));
    }
    const n = Math.min(500, Math.max(0, Number(count) || 0));
    return Array.from({ length: n }, (_, i) => {
      const num = s + i;
      const url = pattern.includes("{n}")
        ? pattern.replaceAll("{n}", String(num))
        : pattern || (rotate ? SAMPLE_VIDEOS[i % SAMPLE_VIDEOS.length]! : "");
      return { number: num, video_url: url };
    });
  })();

  const run = async () => {
    if (!planned.length) return;
    if (planned.some((p) => !p.video_url)) {
      toast.error(t("Every episode needs a video URL"));
      return;
    }
    setRunning(true);
    setDone(0);
    setFailed([]);
    const fails: string[] = [];
    for (const [i, p] of planned.entries()) {
      try {
        await api.post(basePath, {
          number: p.number,
          title: `Episode ${p.number}`,
          video_url: p.video_url,
          duration_seconds: duration ? Number(duration) : null,
        });
      } catch (e) {
        fails.push(`EP ${p.number}: ${errorMessage(e)}`);
      }
      setDone(i + 1);
    }
    setFailed(fails);
    setRunning(false);
    const ok = planned.length - fails.length;
    if (ok) toast.success(t(ok === 1 ? "Added {n} episode" : "Added {n} episodes", { n: ok }));
    if (fails.length) toast.error(t(fails.length === 1 ? "{n} episode failed" : "{n} episodes failed", { n: fails.length }));
    onDone();
    if (!fails.length) onClose();
  };

  const pct = planned.length ? Math.round((done / planned.length) * 100) : 0;

  return (
    <Modal open={open} onClose={running ? () => {} : onClose} title={t("Bulk add episodes")} size="lg">
      <div className="grid gap-4">
        <div className="grid grid-cols-2 gap-1 rounded-xl bg-surface-2 p-1 text-sm font-semibold">
          {(
            [
              ["range", "Numbered range"],
              ["list", "Paste URL list"],
            ] as const
          ).map(([m, label]) => (
            <button
              key={m}
              type="button"
              onClick={() => setMode(m)}
              disabled={running}
              className={cn("rounded-lg py-2 transition", mode === m ? "bg-surface text-text shadow" : "text-text-dim hover:text-text")}
            >
              {t(label)}
            </button>
          ))}
        </div>

        <div className="grid gap-3 sm:grid-cols-3">
          <Field label={t("Start at episode")} htmlFor="bulk-start">
            <Input id="bulk-start" type="number" min={1} value={start} onChange={(e) => setStart(e.target.value)} disabled={running} />
          </Field>
          {mode === "range" && (
            <Field label={t("How many")} htmlFor="bulk-count">
              <Input id="bulk-count" type="number" min={1} max={500} value={count} onChange={(e) => setCount(e.target.value)} disabled={running} />
            </Field>
          )}
          <Field label={t("Duration (sec)")} htmlFor="bulk-dur">
            <Input id="bulk-dur" type="number" min={0} value={duration} onChange={(e) => setDuration(e.target.value)} placeholder={t("optional")} disabled={running} />
          </Field>
        </div>

        {mode === "range" ? (
          <>
            <Field
              label={t("Video URL or pattern")}
              htmlFor="bulk-pattern"
              hint={
                <>
                  {t("Use")} <code className="rounded bg-surface-2 px-1">{"{n}"}</code> {t("for the episode number, e.g.")}{" "}
                  https://cdn.example.com/kilima/ep{"{n}"}.mp4. {t("Leave empty to use sample videos.")}
                </>
              }
            >
              <Input id="bulk-pattern" value={pattern} onChange={(e) => setPattern(e.target.value)} placeholder="https://…/ep{n}.mp4" disabled={running} />
            </Field>
            {!pattern && <Checkbox checked={rotate} onChange={setRotate} label={t("Rotate through Afriva sample videos")} />}
          </>
        ) : (
          <Field
            label={t("One video URL per line")}
            htmlFor="bulk-urls"
            hint={t(planned.length === 1 ? "{n} episode will be created" : "{n} episodes will be created", { n: planned.length })}
          >
            <Textarea
              id="bulk-urls"
              rows={8}
              value={urls}
              onChange={(e) => setUrls(e.target.value)}
              placeholder={SAMPLE_VIDEOS.join("\n")}
              className="font-mono text-xs"
              disabled={running}
            />
          </Field>
        )}

        {planned.length > 0 && !running && done === 0 && (
          <p className="text-xs text-text-muted">
            {t("Will create episodes {from}–{to}.", {
              from: planned[0]!.number,
              to: planned[planned.length - 1]!.number,
            })}
          </p>
        )}

        {(running || done > 0) && (
          <div>
            <div className="mb-1.5 flex justify-between text-xs text-text-muted">
              <span>{running ? t("Creating episodes…") : t("Finished")}</span>
              <span>
                {done}/{planned.length}
              </span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-surface-2" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
              <div className="h-full rounded-full bg-primary transition-all duration-200" style={{ width: `${pct}%` }} />
            </div>
          </div>
        )}
        {failed.length > 0 && (
          <ul className="max-h-32 overflow-y-auto rounded-xl border border-danger/30 bg-danger/10 p-3 text-xs text-danger">
            {failed.map((f) => (
              <li key={f}>{f}</li>
            ))}
          </ul>
        )}

        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose} disabled={running}>
            {done > 0 && !running ? t("Close") : t("Cancel")}
          </Button>
          <Button type="button" onClick={run} loading={running} disabled={!planned.length}>
            {planned.length === 1
              ? t("Add {n} episode", { n: 1 })
              : planned.length
                ? t("Add {n} episodes", { n: planned.length })
                : t("Add episodes")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
