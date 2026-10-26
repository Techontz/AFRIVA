"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { Card, PageHeader } from "@/components/portal/Kit";
import { LiveFlags, Notice, ReviewStatusPill, ReviewTimeline, VideoPreview, VideoStatusPill } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { Pill, Skeleton } from "@/components/ui/Feedback";
import { Checkbox, Field, Textarea } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatDate, formatDuration } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { AGE_RATING_LABEL, hasPerm } from "@/lib/portal";
import type { Episode, ManagedDrama } from "@/lib/types";

type Decision = "approve" | "request_changes" | "reject";

const DECISIONS: { key: Decision; label: string; variant: "primary" | "secondary" | "danger" }[] = [
  { key: "approve", label: "Approve", variant: "primary" },
  { key: "request_changes", label: "Request changes", variant: "secondary" },
  { key: "reject", label: "Reject", variant: "danger" },
];

const PENDING = ["submitted", "in_review"];

export default function ReviewDetailPage() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  const { user } = useAuth();
  const { data, loading, error, reload, mutate } = useApi<ManagedDrama>(`/admin/reviews/${id}`);
  const [selected, setSelected] = useState<Episode | null>(null);
  const [decision, setDecision] = useState<Decision | null>(null);
  const [notes, setNotes] = useState("");
  const [onlyEpisodes, setOnlyEpisodes] = useState<number[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [errors, setErrors] = useState<string[]>([]);

  const d = data;
  const pendingEps = d?.episodes.filter((e) => PENDING.includes(e.review_status ?? "")) ?? [];
  const seriesPending = PENDING.includes(d?.review_status ?? "");
  const hasWork = seriesPending || pendingEps.length > 0;
  const current = selected ?? pendingEps[0] ?? d?.episodes[0] ?? null;

  const run = async (key: string, fn: () => Promise<ManagedDrama | unknown>, ok: string) => {
    setBusy(key);
    try {
      const res = await fn();
      if (res && typeof res === "object" && "episodes" in res) mutate(() => res as ManagedDrama);
      else reload();
      toast.success(t(ok));
      return true;
    } catch (e) {
      if (e instanceof ApiError && e.errors) setErrors(Object.values(e.errors).flat());
      toast.error(errorMessage(e));
      return false;
    } finally {
      setBusy(null);
    }
  };

  const verify = (e: Episode) =>
    run(`verify-${e.id}`, async () => {
      await api.post(`/admin/episodes/${e.id}/verify-playback`);
      reload();
    }, "Playback checked");

  const decide = async () => {
    if (!decision) return;
    setErrors([]);
    const ok = await run(
      "decide",
      () =>
        api.post<ManagedDrama>(`/admin/reviews/${id}/decide`, {
          decision,
          notes: notes || null,
          episode_ids: onlyEpisodes.length ? onlyEpisodes : null,
        }),
      decision === "approve" ? "Approved" : decision === "reject" ? "Rejected" : "Changes requested",
    );
    if (ok) {
      setDecision(null);
      setNotes("");
      setOnlyEpisodes([]);
    }
  };

  return (
    <>
      <PageHeader
        back={
          <Link href="/admin/reviews" className="inline-flex items-center gap-1 text-xs font-semibold text-text-muted hover:text-text">
            <Icon name="chevron-left" size={14} /> {t("Review")}
          </Link>
        }
        title={d?.title ?? t("Review")}
        description={d ? `${d.company?.name ?? ""} · ${t("Sent {date}", { date: formatDate(d.submitted_at, true) })}` : undefined}
        actions={
          d && (
            <>
              <ReviewStatusPill status={d.review_status} />
              <LiveFlags drama={d} />
              {d.review_status === "submitted" && (
                <Button size="sm" variant="secondary" loading={busy === "start"} onClick={() => run("start", () => api.post<ManagedDrama>(`/admin/reviews/${id}/start`), "Review started")}>
                  {t("Start review")}
                </Button>
              )}
              {hasWork &&
                DECISIONS.map((x) => (
                  <Button key={x.key} size="sm" variant={x.variant} onClick={() => setDecision(x.key)}>
                    {t(x.label)}
                  </Button>
                ))}
              {d.review_status === "approved" && hasPerm(user, "publish") && (
                <Button size="sm" variant="secondary" href={`/admin/dramas?publish=${d.id}`}>
                  {t("Publishing rules")}
                </Button>
              )}
            </>
          )
        }
      />

      {loading && !d ? (
        <Skeleton className="h-[480px] rounded-2xl" />
      ) : error && !d ? (
        <LoadError onRetry={reload} />
      ) : d ? (
        <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]">
          <div className="flex min-w-0 flex-col gap-4">
            {!d.company_agreement_accepted && (
              <Notice tone="warning" title="The creator has not accepted the current revenue agreement" />
            )}
            {!hasWork && <Notice tone="info">{t("Nothing in this series is waiting for a decision.")}</Notice>}
            <Card title="Episodes">
              <p className="mb-3 text-xs text-text-muted">
                {t("Watch each episode and confirm playback works before approving. Approval needs every episode under review to be checked.")}
              </p>
              <div className="grid gap-4 lg:grid-cols-[280px_minmax(0,1fr)]">
                <div>
                  {current ? (
                    <>
                      <VideoPreview key={current.id} sources={current.sources ?? []} subtitleUrl={current.subtitle_url} />
                      <p className="mt-2 text-sm font-semibold">
                        {t("Episode {n}", { n: current.number })} · {current.title}
                      </p>
                    </>
                  ) : (
                    <p className="text-sm text-text-dim">{t("No episodes")}</p>
                  )}
                </div>
                <ul className="max-h-[560px] divide-y divide-border overflow-y-auto rounded-xl border border-border">
                  {d.episodes.map((e) => {
                    const pending = PENDING.includes(e.review_status ?? "");
                    return (
                      <li
                        key={e.id}
                        className={cn("flex flex-wrap items-center gap-2 px-3 py-2.5 text-sm", current?.id === e.id && "bg-surface-2")}
                      >
                        <button onClick={() => setSelected(e)} className="flex min-w-0 flex-1 items-center gap-2 text-left">
                          <span className="grid h-8 min-w-8 place-items-center rounded-lg bg-surface-2 text-xs font-extrabold">{e.number}</span>
                          <span className="min-w-0">
                            <span className="block truncate font-semibold">{e.title}</span>
                            <span className="text-xs text-text-dim">{formatDuration(e.duration_seconds)}</span>
                          </span>
                        </button>
                        <ReviewStatusPill status={e.review_status} />
                        <VideoStatusPill status={e.video_status} error={e.video_error} />
                        {e.playback_verified_at ? (
                          <Pill tone="success">
                            <Icon name="check" size={11} /> {t("Checked")}
                          </Pill>
                        ) : pending ? (
                          <Button size="sm" variant="outline" loading={busy === `verify-${e.id}`} disabled={e.video_status !== "ready"} onClick={() => verify(e)}>
                            {t("Playback checked")}
                          </Button>
                        ) : null}
                      </li>
                    );
                  })}
                </ul>
              </div>
            </Card>
          </div>

          <div className="flex flex-col gap-4">
            <Card title="Details">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              {d.poster_url && <img src={d.poster_url} alt="" className="mb-3 aspect-[3/4] w-32 rounded-lg object-cover" />}
              <dl className="grid grid-cols-[110px_1fr] gap-x-3 gap-y-2 text-sm">
                <dt className="text-text-dim">{t("Genre")}</dt>
                <dd>{d.categories.map((c) => c.name).join(", ") || "—"}</dd>
                <dt className="text-text-dim">{t("Age rating")}</dt>
                <dd>{d.age_rating ? t(AGE_RATING_LABEL[d.age_rating]) : "—"}</dd>
                <dt className="text-text-dim">{t("Language")}</dt>
                <dd>{d.language ?? "—"}</dd>
                <dt className="text-text-dim">{t("Rights declared")}</dt>
                <dd>{d.rights_declared_at ? formatDate(d.rights_declared_at, true) : t("No")}</dd>
                <dt className="text-text-dim">{t("Tags")}</dt>
                <dd>{d.tags.join(", ") || "—"}</dd>
              </dl>
              <p className="mt-3 whitespace-pre-line text-sm text-text-muted">{d.synopsis || t("No synopsis")}</p>
              {d.trailer_url && (
                <div className="mt-3">
                  <p className="mb-1 text-xs font-semibold text-text-dim">{t("Trailer")}</p>
                  <VideoPreview sources={[{ quality: "auto", label: "Auto", url: d.trailer_url, type: d.trailer_url.includes(".m3u8") ? "hls" : "mp4" }]} />
                </div>
              )}
            </Card>
            <Card title="Review history">
              <ReviewTimeline reviews={d.reviews ?? []} />
            </Card>
          </div>
        </div>
      ) : null}

      <Modal open={!!decision} onClose={() => setDecision(null)} title={decision ? DECISIONS.find((x) => x.key === decision)!.label : ""}>
        <div className="flex flex-col gap-4 text-sm">
          <p className="text-text-muted">
            {decision === "approve"
              ? t("Approved work can then be published with its publishing rules.")
              : decision === "reject"
                ? t("Rejected work cannot be resubmitted. Explain why to the creator.")
                : t("The creator will see your notes, fix the work and send it again.")}
          </p>
          {pendingEps.length > 1 && (
            <div>
              <p className="mb-2 font-semibold">{t("Apply to (leave all unticked for everything under review)")}</p>
              <div className="flex max-h-40 flex-wrap gap-2 overflow-y-auto">
                {pendingEps.map((e) => (
                  <Checkbox
                    key={e.id}
                    checked={onlyEpisodes.includes(e.id)}
                    onChange={(v) => setOnlyEpisodes((l) => (v ? [...l, e.id] : l.filter((x) => x !== e.id)))}
                    label={t("EP {n}", { n: e.number })}
                  />
                ))}
              </div>
            </div>
          )}
          <Field label={decision === "approve" ? "Notes (optional)" : "Notes for the creator"}>
            <Textarea rows={4} value={notes} onChange={(e) => setNotes(e.target.value)} />
          </Field>
          {errors.length > 0 && (
            <ul className="list-disc space-y-1 rounded-xl border border-danger/30 bg-danger/10 py-3 pl-8 pr-3 text-xs text-danger">
              {errors.map((m) => (
                <li key={m}>{m}</li>
              ))}
            </ul>
          )}
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDecision(null)}>
              {t("Cancel")}
            </Button>
            <Button
              variant={decision === "reject" ? "danger" : "primary"}
              loading={busy === "decide"}
              disabled={decision !== "approve" && !notes.trim()}
              onClick={decide}
            >
              {t("Confirm")}
            </Button>
          </div>
        </div>
      </Modal>
    </>
  );
}
