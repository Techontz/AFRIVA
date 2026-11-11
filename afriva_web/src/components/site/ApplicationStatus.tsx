"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { type ApplicationSample, type CreatorApplication, mmss, pct, uploadSample } from "@/lib/creator";
import { STUDIO_URL } from "@/lib/portals";
import { Button } from "../ui/Button";
import { Spinner } from "../ui/Feedback";
import { ConfirmModal } from "../ui/Modal";

const MAX_BYTES = 500 * 1024 * 1024;

/** The applicant's request to post: review status and the 10 sample video slots (uploads go straight to Bunny). */
export function ApplicationStatus({ inStudio = false }: { inStudio?: boolean }) {
  const { status: t, form: tf } = useT().creator;
  const { user, loading: authLoading, refresh } = useAuth();
  const [app, setApp] = useState<CreatorApplication | null | undefined>(undefined);
  const [uploads, setUploads] = useState<Record<string, number>>({});
  const [confirm, setConfirm] = useState<ApplicationSample | null>(null);
  const [deleting, setDeleting] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    try {
      setApp(await api.get<CreatorApplication | null>("/me/studio-application"));
    } catch (e) {
      toast.error(errorMessage(e));
      setApp((a) => a ?? null);
    }
  }, []);

  useEffect(() => {
    if (!user) return;
    let alive = true;
    api
      .get<CreatorApplication | null>("/me/studio-application")
      .then((a) => alive && setApp(a))
      .catch((e) => {
        if (!alive) return;
        toast.error(errorMessage(e));
        setApp((a) => a ?? null);
      });
    return () => {
      alive = false;
    };
  }, [user]);

  // While Bunny is still processing, check again every 15 seconds.
  const busy = !!app?.samples.some((s) => s.status === "uploading" || s.status === "processing");
  const uploading = Object.keys(uploads).length > 0;
  useEffect(() => {
    if (!busy || uploading) return;
    const id = window.setInterval(() => void load(), 15000);
    return () => window.clearInterval(id);
  }, [busy, uploading, load]);

  const startUploads = async (files: FileList | null) => {
    if (!files || !app) return;
    const room = app.samples_summary.required - app.samples.length - Object.keys(uploads).length;
    const list = Array.from(files).slice(0, Math.max(0, room));
    for (const file of list) {
      if (!file.type.startsWith("video/")) {
        toast.error(t.notVideo);
        continue;
      }
      if (file.size > MAX_BYTES) {
        toast.error(t.tooBig);
        continue;
      }
      const key = `${file.name}-${file.size}-${Date.now()}`;
      setUploads((u) => ({ ...u, [key]: 0 }));
      try {
        await uploadSample(file, (p) => setUploads((u) => ({ ...u, [key]: p })));
      } catch (e) {
        toast.error(errorMessage(e));
      } finally {
        setUploads((u) => {
          const next = { ...u };
          delete next[key];
          return next;
        });
        void load();
      }
    }
    if (fileInput.current) fileInput.current.value = "";
  };

  const remove = async () => {
    if (!confirm) return;
    setDeleting(true);
    try {
      await api.del(`/me/studio-application/samples/${confirm.id}`);
      setConfirm(null);
      await load();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setDeleting(false);
    }
  };

  const wrap = (children: React.ReactNode) => (
    <div className={inStudio ? "mx-auto w-full max-w-3xl" : "mx-auto w-full max-w-3xl px-4 py-10"}>
      <h1 className="mb-6 text-2xl font-extrabold tracking-tight">{t.title}</h1>
      {children}
    </div>
  );

  if (authLoading || (user && app === undefined)) {
    return wrap(
      <div className="grid min-h-[30vh] place-items-center">
        <Spinner />
      </div>,
    );
  }
  if (!user) {
    return wrap(
      <div className="space-y-4 rounded-3xl border border-border bg-bg p-6">
        <p className="text-sm text-text-muted">{t.loginFirst}</p>
        <Button href="/login?next=%2Fapply%2Fstatus">{tf.logIn}</Button>
      </div>,
    );
  }
  if (!app) {
    return wrap(
      <div className="space-y-4 rounded-3xl border border-border bg-bg p-6">
        <p className="text-sm text-text-muted">{t.none}</p>
        <Button href="/apply">{t.start}</Button>
      </div>,
    );
  }

  const s = app.samples_summary;
  const open = app.status === "pending";
  const pendingUploads = Object.values(uploads);
  const free = Math.max(0, s.required - app.samples.length - pendingUploads.length);
  const hint =
    app.review_status === "approved"
      ? t.approvedHint
      : app.review_status === "rejected"
        ? t.rejectedHint
        : app.review_status === "ready_for_review"
          ? t.readyHint
          : t.pendingHint;
  const studioHref = user.role === "company" ? "/studio" : `${STUDIO_URL}/login`;

  return wrap(
    <div className="space-y-5">
      <div className="space-y-3 rounded-3xl border border-border bg-bg p-6">
        <div className="flex flex-wrap items-center gap-3">
          <span
            className={`rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wider ${
              app.review_status === "rejected" ? "bg-danger/15 text-danger" : app.review_status === "approved" ? "bg-surface-2 text-text" : "bg-primary/15 text-primary"
            }`}
          >
            {t.review[app.review_status]}
          </span>
          {app.company && <span className="text-sm font-semibold">{app.company.name}</span>}
        </div>
        <p className="text-sm text-text-muted">{hint}</p>
        {app.review_status === "rejected" && app.rejection_reason && <p className="text-sm text-text">{fmt(t.reason, { reason: app.rejection_reason })}</p>}
        <p className="text-xs text-text-dim">
          {fmt(t.split, { creator: pct(app.revenue_split.creator_percent), platform: pct(app.revenue_split.platform_percent) })}
        </p>
        {app.review_status === "approved" && (
          <div className="space-y-2 pt-1">
            {user.role !== "company" && <p className="text-xs text-text-dim">{t.studioLogin}</p>}
            {inStudio ? (
              <Button onClick={() => void refresh()}>{t.openStudio}</Button>
            ) : (
              <Button href={studioHref}>{t.openStudio}</Button>
            )}
          </div>
        )}
      </div>

      {app.status !== "rejected" && (
        <div className="space-y-4 rounded-3xl border border-border bg-bg p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="font-bold">{t.samples}</h2>
              <p className="text-sm text-text-muted">{fmt(t.progress, { valid: s.valid, required: s.required })}</p>
            </div>
            <div className="flex gap-2">
              <Button variant="ghost" size="sm" onClick={() => void load()}>
                {t.refresh}
              </Button>
              {open && free > 0 && (
                <>
                  <input ref={fileInput} type="file" accept="video/*" multiple className="hidden" onChange={(e) => void startUploads(e.target.files)} />
                  <Button size="sm" onClick={() => fileInput.current?.click()}>
                    {t.upload}
                  </Button>
                </>
              )}
            </div>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-surface-2">
            <div className="h-full rounded-full bg-primary transition-all" style={{ width: `${Math.min(100, (s.valid / s.required) * 100)}%` }} />
          </div>
          <ul className="divide-y divide-border">
            {app.samples.map((sample, i) => {
              const bad = sample.length_check === "too_short" ? t.tooShort : sample.length_check === "too_long" ? t.tooLong : null;
              const label =
                sample.status === "failed" ? t.failed : sample.status === "ready" ? (bad ?? t.ready) : t.processing;
              return (
                <li key={sample.id} className="flex items-center gap-3 py-3 text-sm">
                  <span className="w-20 shrink-0 font-semibold">{fmt(t.slot, { n: i + 1 })}</span>
                  <span className="min-w-0 flex-1 truncate text-text-muted">{sample.title}</span>
                  {sample.duration_seconds ? <span className="tabular-nums text-text-muted">{mmss(sample.duration_seconds)}</span> : null}
                  <span className={sample.valid ? "text-text" : sample.status === "ready" || sample.status === "failed" ? "text-danger" : "text-text-dim"}>{label}</span>
                  {open && (
                    <Button variant="ghost" size="sm" onClick={() => setConfirm(sample)}>
                      {t.replace}
                    </Button>
                  )}
                </li>
              );
            })}
            {pendingUploads.map((p, i) => (
              <li key={`up-${i}`} className="flex items-center gap-3 py-3 text-sm">
                <span className="w-20 shrink-0 font-semibold">{fmt(t.slot, { n: app.samples.length + i + 1 })}</span>
                <span className="flex-1 text-text-muted">{fmt(t.uploading, { pct: p })}</span>
              </li>
            ))}
            {open &&
              Array.from({ length: free }).map((_, i) => (
                <li key={`free-${i}`} className="flex items-center gap-3 py-3 text-sm text-text-dim">
                  <span className="w-20 shrink-0 font-semibold">{fmt(t.slot, { n: app.samples.length + pendingUploads.length + i + 1 })}</span>
                  <span className="flex-1">-</span>
                </li>
              ))}
          </ul>
        </div>
      )}
      <ConfirmModal
        open={!!confirm}
        onClose={() => setConfirm(null)}
        onConfirm={() => void remove()}
        title={t.replace}
        message={t.confirmDelete}
        confirmLabel={t.replace}
        danger
        loading={deleting}
      />
    </div>,
  );
}
