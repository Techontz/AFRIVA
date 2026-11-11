"use client";

import { useEffect, useState, type FormEvent } from "react";
import { toast } from "sonner";
import { EpisodeVideoInput, UploadProgress, type EpisodeVideoValue } from "@/components/portal/EpisodeVideo";
import { OrientationPicker } from "@/components/portal/Orientation";
import { Button } from "@/components/ui/Button";
import { Checkbox, Field, Input, Textarea } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { useT } from "@/i18n/client";
import { fmt, plural } from "@/i18n/format";
import { api, ApiError, errorMessage } from "@/lib/api";
import { cn } from "@/lib/format";
import type { Episode, EpisodeOrientation } from "@/lib/types";
import { useEpisodeVideoUpload, type PortalScope } from "@/lib/videoUpload";

export const SAMPLE_VIDEOS = [
  "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
  "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
  "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
];

interface EpisodeFormState {
  number: string;
  title: string;
  video: EpisodeVideoValue;
  thumbnail_url: string;
  duration_seconds: string;
  is_free: boolean;
  orientation: EpisodeOrientation;
}

function EpisodeForm({
  scope,
  dramaId,
  episode,
  defaultNumber,
  freeEpisodes,
  onSaved,
  onCancel,
  onBusy,
}: {
  scope: PortalScope;
  dramaId: string | number;
  episode?: Episode | null;
  defaultNumber: number;
  freeEpisodes: number;
  onSaved: (e: Episode | null) => void;
  onCancel: () => void;
  onBusy: (busy: boolean) => void;
}) {
  const initialUrl = episode?.bunny_video_id ? "" : (episode?.video_url ?? "");
  const [f, setF] = useState<EpisodeFormState>(() => ({
    number: String(episode?.number ?? defaultNumber),
    title: episode?.title ?? "",
    // Upload is the primary path; keep "paste a URL" for episodes that already use one.
    video: { mode: initialUrl ? "url" : "upload", url: initialUrl, file: null },
    thumbnail_url: episode?.thumbnail_url ?? "",
    duration_seconds: episode?.duration_seconds ? String(episode.duration_seconds) : "",
    is_free: episode?.is_free ?? defaultNumber <= freeEpisodes,
    orientation: episode?.orientation ?? "portrait",
  }));
  const t = useT().studio.episodeForm;
  const tv = useT().portal.video;
  const tc = useT().common;
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  /** Episode row that exists on the API while its video is uploading. */
  const [saved, setSaved] = useState<Episode | null>(null);
  const up = useEpisodeVideoUpload();
  const set = <K extends keyof EpisodeFormState>(k: K, v: EpisodeFormState[K]) => setF((s) => ({ ...s, [k]: v }));
  const err = (k: string) => errors[k]?.[0] ?? null;
  const base = `/${scope}/dramas/${dramaId}/episodes`;

  useEffect(() => {
    onBusy(saving || up.active);
  }, [saving, up.active, onBusy]);

  const uploadFor = async (ep: Episode, file: File) => {
    const done = await up.start(scope, dramaId, ep.id, file);
    if (done) {
      toast.success(tv.done);
      onSaved(done);
    }
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const { mode, url, file } = f.video;
    if (!episode && (mode === "upload" ? !file : !url)) {
      setErrors({ video: [t.videoRequired] });
      return;
    }
    setSaving(true);
    setErrors({});
    const body: Record<string, unknown> = {
      number: Number(f.number),
      title: f.title || null,
      thumbnail_url: f.thumbnail_url || null,
      duration_seconds: f.duration_seconds ? Number(f.duration_seconds) : null,
      is_free: f.is_free,
      orientation: f.orientation,
    };
    // Only send video_url when the URL path is used and it actually changed,
    // so saving metadata never clobbers a Bunny-hosted video.
    if (mode === "url" && (url || null) !== (initialUrl || null)) body.video_url = url || null;
    let ep: Episode | null = null;
    try {
      ep = episode
        ? await api.put<Episode>(`${base}/${episode.id}`, body)
        : await api.post<Episode>(base, body);
      ep = ep ?? episode ?? null;
    } catch (e) {
      if (e instanceof ApiError && e.errors) setErrors(e.errors);
      toast.error(errorMessage(e));
      setSaving(false);
      return;
    }
    setSaving(false);
    const willUpload = mode === "upload" && file && ep;
    if (!willUpload) {
      toast.success(episode ? t.updated : fmt(t.added, { n: Number(f.number) }));
      onSaved(ep);
      return;
    }
    // Episode exists now (create-then-upload); stream the file to Bunny.
    toast.success(episode ? t.updated : fmt(t.added, { n: Number(f.number) }));
    setSaved(ep);
    await uploadFor(ep!, file!);
  };

  if (saved && f.video.file) {
    const finished = up.state.phase === "cancelled" || up.state.phase === "error";
    return (
      <div className="grid gap-4">
        <UploadProgress
          state={up.state}
          onCancel={up.cancel}
          onResume={up.resume}
          onRetry={() => void uploadFor(saved, f.video.file!)}
        />
        {finished && <p className="text-xs text-text-muted">{tv.savedUploadFailed}</p>}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" disabled={up.active} onClick={() => onSaved(saved)}>
            {tc.actions.close}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="grid gap-4">
      <div className="grid grid-cols-[110px_1fr] gap-3">
        <Field label={t.number} htmlFor="ep-number" error={err("number")}>
          <Input id="ep-number" type="number" min={1} required value={f.number} onChange={(e) => set("number", e.target.value)} />
        </Field>
        <Field label={t.titleOptional} htmlFor="ep-title" error={err("title")}>
          <Input id="ep-title" value={f.title} onChange={(e) => set("title", e.target.value)} placeholder={fmt(tc.episodeN, { n: f.number })} />
        </Field>
      </div>
      <OrientationPicker value={f.orientation} onChange={(v) => set("orientation", v)} disabled={saving} />
      <EpisodeVideoInput label={t.video} value={f.video} onChange={(v) => set("video", v)} episode={episode} disabled={saving} />
      {(err("video") || err("video_url")) && <p className="-mt-2 text-xs text-danger">{err("video") || err("video_url")}</p>}
      <div className="grid gap-3 sm:grid-cols-[1fr_140px]">
        <Field label={t.thumbnailUrl} htmlFor="ep-thumb">
          <Input id="ep-thumb" type="url" value={f.thumbnail_url} onChange={(e) => set("thumbnail_url", e.target.value)} placeholder="https://…" />
        </Field>
        <Field label={t.duration} htmlFor="ep-dur" error={err("duration_seconds")}>
          <Input id="ep-dur" type="number" min={0} value={f.duration_seconds} onChange={(e) => set("duration_seconds", e.target.value)} placeholder="90" />
        </Field>
      </div>
      <Checkbox checked={f.is_free} onChange={(v) => set("is_free", v)} label={t.freeToWatch} />
      <div className="flex justify-end gap-2 pt-1">
        <Button type="button" variant="ghost" onClick={onCancel}>
          {tc.actions.cancel}
        </Button>
        <Button type="submit" loading={saving}>
          {episode ? t.save : t.add}
        </Button>
      </div>
    </form>
  );
}

export function EpisodeModal({
  open,
  onClose,
  scope = "studio",
  ...props
}: {
  open: boolean;
  onClose: () => void;
  scope?: PortalScope;
  dramaId: string | number;
  episode?: Episode | null;
  defaultNumber: number;
  freeEpisodes: number;
  onSaved: (e: Episode | null) => void;
}) {
  const t = useT().studio.episodeForm;
  const [busy, setBusy] = useState(false);
  return (
    <Modal
      open={open}
      onClose={busy ? () => {} : onClose}
      title={props.episode ? fmt(t.editTitle, { n: props.episode.number }) : t.add}
    >
      {open && <EpisodeForm key={props.episode?.id ?? "new"} scope={scope} {...props} onCancel={onClose} onBusy={setBusy} />}
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
  const t = useT().studio.bulk;
  const tc = useT().common;
  const [mode, setMode] = useState<BulkMode>("range");
  const [start, setStart] = useState(String(startNumber));
  const [count, setCount] = useState("10");
  const [pattern, setPattern] = useState("");
  const [rotate, setRotate] = useState(true);
  const [urls, setUrls] = useState("");
  const [duration, setDuration] = useState("");
  const [orientation, setOrientation] = useState<EpisodeOrientation>("portrait");
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
      toast.error(t.needsVideo);
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
          title: fmt(tc.episodeN, { n: p.number }),
          video_url: p.video_url,
          duration_seconds: duration ? Number(duration) : null,
          is_free: p.number <= freeEpisodes,
          orientation,
        });
      } catch (e) {
        fails.push(`EP ${p.number}: ${errorMessage(e)}`);
      }
      setDone(i + 1);
    }
    setFailed(fails);
    setRunning(false);
    const ok = planned.length - fails.length;
    if (ok) toast.success(plural(ok, t.added));
    if (fails.length) toast.error(plural(fails.length, t.failed));
    onDone();
    if (!fails.length) onClose();
  };

  const pct = planned.length ? Math.round((done / planned.length) * 100) : 0;

  return (
    <Modal open={open} onClose={running ? () => {} : onClose} title={t.title} size="lg">
      <div className="grid gap-4">
        <div className="grid grid-cols-2 gap-1 rounded-xl bg-surface-2 p-1 text-sm font-semibold">
          {(
            [
              ["range", t.range],
              ["list", t.list],
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
          <Field label={t.start} htmlFor="bulk-start">
            <Input id="bulk-start" type="number" min={1} value={start} onChange={(e) => setStart(e.target.value)} disabled={running} />
          </Field>
          {mode === "range" && (
            <Field label={t.howMany} htmlFor="bulk-count">
              <Input id="bulk-count" type="number" min={1} max={500} value={count} onChange={(e) => setCount(e.target.value)} disabled={running} />
            </Field>
          )}
          <Field label={t.duration} htmlFor="bulk-dur">
            <Input id="bulk-dur" type="number" min={0} value={duration} onChange={(e) => setDuration(e.target.value)} placeholder={t.optional} disabled={running} />
          </Field>
        </div>

        <OrientationPicker value={orientation} onChange={setOrientation} disabled={running} />

        {mode === "range" ? (
          <>
            <Field
              label={t.pattern}
              htmlFor="bulk-pattern"
              hint={
                <>
                  {t.patternHintBefore} <code className="rounded bg-surface-2 px-1">{"{n}"}</code> {t.patternHintAfter}
                </>
              }
            >
              <Input id="bulk-pattern" value={pattern} onChange={(e) => setPattern(e.target.value)} placeholder="https://…/ep{n}.mp4" disabled={running} />
            </Field>
            {!pattern && <Checkbox checked={rotate} onChange={setRotate} label={t.rotate} />}
          </>
        ) : (
          <Field label={t.perLine} htmlFor="bulk-urls" hint={plural(planned.length, t.willCreate)}>
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
            {fmt(t.plan, { from: planned[0]!.number, to: planned[planned.length - 1]!.number, free: freeEpisodes })}
          </p>
        )}

        {(running || done > 0) && (
          <div>
            <div className="mb-1.5 flex justify-between text-xs text-text-muted">
              <span>{running ? t.creating : t.finished}</span>
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
            {done > 0 && !running ? tc.actions.close : tc.actions.cancel}
          </Button>
          <Button type="button" onClick={run} loading={running} disabled={!planned.length}>
            {planned.length ? plural(planned.length, t.addN) : t.addNone}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
