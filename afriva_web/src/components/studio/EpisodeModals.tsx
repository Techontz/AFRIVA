"use client";

import { useState, type FormEvent } from "react";
import { toast } from "sonner";
import { appendMedia, MediaInput, type MediaValue } from "@/components/portal/MediaInput";
import { Button } from "@/components/ui/Button";
import { Checkbox, Field, Input, Textarea } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { api, ApiError, errorMessage } from "@/lib/api";
import { cn } from "@/lib/format";
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
  thumbnail_url: string;
  duration_seconds: string;
  is_free: boolean;
}

function EpisodeForm({
  dramaId,
  episode,
  defaultNumber,
  freeEpisodes,
  onSaved,
  onCancel,
}: {
  dramaId: string | number;
  episode?: Episode | null;
  defaultNumber: number;
  freeEpisodes: number;
  onSaved: (e: Episode | null) => void;
  onCancel: () => void;
}) {
  const [f, setF] = useState<EpisodeFormState>(() => ({
    number: String(episode?.number ?? defaultNumber),
    title: episode?.title ?? "",
    video: { url: episode?.video_url ?? "", file: null },
    thumbnail_url: episode?.thumbnail_url ?? "",
    duration_seconds: episode?.duration_seconds ? String(episode.duration_seconds) : "",
    is_free: episode?.is_free ?? defaultNumber <= freeEpisodes,
  }));
  const [saving, setSaving] = useState(false);
  const [progress, setProgress] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  const set = <K extends keyof EpisodeFormState>(k: K, v: EpisodeFormState[K]) => setF((s) => ({ ...s, [k]: v }));
  const err = (k: string) => errors[k]?.[0] ?? null;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!episode && !f.video.url && !f.video.file) {
      setErrors({ video: ["Add a video URL or upload a file"] });
      return;
    }
    setSaving(true);
    setErrors({});
    const scalar = {
      number: Number(f.number),
      title: f.title || null,
      thumbnail_url: f.thumbnail_url || null,
      duration_seconds: f.duration_seconds ? Number(f.duration_seconds) : null,
      is_free: f.is_free,
    };
    let body: FormData | Record<string, unknown>;
    if (f.video.file) {
      const fd = new FormData();
      for (const [k, v] of Object.entries(scalar)) {
        if (v === null) continue;
        fd.append(k, typeof v === "boolean" ? (v ? "1" : "0") : String(v));
      }
      appendMedia(fd, "video", f.video);
      body = fd;
      setProgress(`Uploading ${(f.video.file.size / 1024 / 1024).toFixed(1)} MB…`);
    } else {
      body = { ...scalar, video_url: f.video.url || null };
    }
    try {
      const saved = episode
        ? await api.put<Episode>(`/studio/dramas/${dramaId}/episodes/${episode.id}`, body)
        : await api.post<Episode>(`/studio/dramas/${dramaId}/episodes`, body);
      toast.success(episode ? "Episode updated" : `Episode ${scalar.number} added`);
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
        <Field label="Number" htmlFor="ep-number" error={err("number")}>
          <Input id="ep-number" type="number" min={1} required value={f.number} onChange={(e) => set("number", e.target.value)} />
        </Field>
        <Field label="Title (optional)" htmlFor="ep-title" error={err("title")}>
          <Input id="ep-title" value={f.title} onChange={(e) => set("title", e.target.value)} placeholder={`Episode ${f.number}`} />
        </Field>
      </div>
      <MediaInput label="Video" kind="video" accept="video/*" value={f.video} onChange={(v) => set("video", v)} />
      {(err("video") || err("video_url")) && <p className="-mt-2 text-xs text-danger">{err("video") || err("video_url")}</p>}
      <div className="grid gap-3 sm:grid-cols-[1fr_140px]">
        <Field label="Thumbnail URL" htmlFor="ep-thumb">
          <Input id="ep-thumb" type="url" value={f.thumbnail_url} onChange={(e) => set("thumbnail_url", e.target.value)} placeholder="https://…" />
        </Field>
        <Field label="Duration (sec)" htmlFor="ep-dur" error={err("duration_seconds")}>
          <Input id="ep-dur" type="number" min={0} value={f.duration_seconds} onChange={(e) => set("duration_seconds", e.target.value)} placeholder="90" />
        </Field>
      </div>
      <Checkbox checked={f.is_free} onChange={(v) => set("is_free", v)} label="Free to watch (no unlock needed)" />
      {progress && <p className="text-xs text-text-muted">{progress}</p>}
      <div className="flex justify-end gap-2 pt-1">
        <Button type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" loading={saving}>
          {episode ? "Save episode" : "Add episode"}
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
  dramaId: string | number;
  episode?: Episode | null;
  defaultNumber: number;
  freeEpisodes: number;
  onSaved: (e: Episode | null) => void;
}) {
  return (
    <Modal open={open} onClose={onClose} title={props.episode ? `Edit episode ${props.episode.number}` : "Add episode"}>
      {open && <EpisodeForm key={props.episode?.id ?? "new"} {...props} onCancel={onClose} />}
    </Modal>
  );
}

type BulkMode = "range" | "list";

export function BulkAddModal({
  open,
  onClose,
  dramaId,
  startNumber,
  freeEpisodes,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  dramaId: string | number;
  startNumber: number;
  freeEpisodes: number;
  onDone: () => void;
}) {
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
      toast.error("Every episode needs a video URL");
      return;
    }
    setRunning(true);
    setDone(0);
    setFailed([]);
    const fails: string[] = [];
    for (const [i, p] of planned.entries()) {
      try {
        await api.post(`/studio/dramas/${dramaId}/episodes`, {
          number: p.number,
          title: `Episode ${p.number}`,
          video_url: p.video_url,
          duration_seconds: duration ? Number(duration) : null,
          is_free: p.number <= freeEpisodes,
        });
      } catch (e) {
        fails.push(`EP ${p.number}: ${errorMessage(e)}`);
      }
      setDone(i + 1);
    }
    setFailed(fails);
    setRunning(false);
    const ok = planned.length - fails.length;
    if (ok) toast.success(`Added ${ok} episode${ok === 1 ? "" : "s"}`);
    if (fails.length) toast.error(`${fails.length} episode${fails.length === 1 ? "" : "s"} failed`);
    onDone();
    if (!fails.length) onClose();
  };

  const pct = planned.length ? Math.round((done / planned.length) * 100) : 0;

  return (
    <Modal open={open} onClose={running ? () => {} : onClose} title="Bulk add episodes" size="lg">
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
              {label}
            </button>
          ))}
        </div>

        <div className="grid gap-3 sm:grid-cols-3">
          <Field label="Start at episode" htmlFor="bulk-start">
            <Input id="bulk-start" type="number" min={1} value={start} onChange={(e) => setStart(e.target.value)} disabled={running} />
          </Field>
          {mode === "range" && (
            <Field label="How many" htmlFor="bulk-count">
              <Input id="bulk-count" type="number" min={1} max={500} value={count} onChange={(e) => setCount(e.target.value)} disabled={running} />
            </Field>
          )}
          <Field label="Duration (sec)" htmlFor="bulk-dur">
            <Input id="bulk-dur" type="number" min={0} value={duration} onChange={(e) => setDuration(e.target.value)} placeholder="optional" disabled={running} />
          </Field>
        </div>

        {mode === "range" ? (
          <>
            <Field
              label="Video URL or pattern"
              htmlFor="bulk-pattern"
              hint={
                <>
                  Use <code className="rounded bg-surface-2 px-1">{"{n}"}</code> for the episode number, e.g.
                  https://cdn.example.com/kilima/ep{"{n}"}.mp4. Leave empty to use sample videos.
                </>
              }
            >
              <Input id="bulk-pattern" value={pattern} onChange={(e) => setPattern(e.target.value)} placeholder="https://…/ep{n}.mp4" disabled={running} />
            </Field>
            {!pattern && <Checkbox checked={rotate} onChange={setRotate} label="Rotate through Afriva sample videos" />}
          </>
        ) : (
          <Field label="One video URL per line" htmlFor="bulk-urls" hint={`${planned.length} episode${planned.length === 1 ? "" : "s"} will be created`}>
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
            Will create episodes {planned[0]!.number}–{planned[planned.length - 1]!.number}. Episodes ≤ {freeEpisodes} are marked free.
          </p>
        )}

        {(running || done > 0) && (
          <div>
            <div className="mb-1.5 flex justify-between text-xs text-text-muted">
              <span>{running ? "Creating episodes…" : "Finished"}</span>
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
            {done > 0 && !running ? "Close" : "Cancel"}
          </Button>
          <Button type="button" onClick={run} loading={running} disabled={!planned.length}>
            Add {planned.length || ""} episode{planned.length === 1 ? "" : "s"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
