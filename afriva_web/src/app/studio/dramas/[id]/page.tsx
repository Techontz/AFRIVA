"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { Card, PageHeader } from "@/components/portal/Kit";
import { LiveFlags, Notice, ReviewStatusPill, ReviewTimeline } from "@/components/portal/ScopeKit";
import { DramaForm } from "@/components/studio/DramaForm";
import { SubmitDialog } from "@/components/studio/SubmitDialog";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Skeleton } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { formatDate } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { isCreatorEditable } from "@/lib/portal";
import type { ManagedDrama } from "@/lib/types";

export default function EditDramaPage() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  const { data, loading, error, reload, mutate } = useApi<ManagedDrama>(`/studio/dramas/${id}`);
  const [submitting, setSubmitting] = useState(false);

  const editable = isCreatorEditable(data?.review_status);
  const pendingEpisodes = data?.episodes.filter((e) => isCreatorEditable(e.review_status)).length ?? 0;
  const canSubmit = !!data && data.review_status !== "rejected" && !["submitted", "in_review"].includes(data.review_status ?? "") && pendingEpisodes > 0;

  return (
    <>
      <PageHeader
        back={
          <Link href="/studio/dramas" className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> {t("My works")}
          </Link>
        }
        title={data?.title ?? t("Series")}
        description={t("Uploading does not mean publishing: every series is reviewed by AFRIVA first.")}
        actions={
          <>
            <Button href={`/studio/dramas/${id}/episodes`} variant="secondary" size="sm">
              <Icon name="list" size={16} /> {t("Episodes")}
            </Button>
            <Button href={`/studio/dramas/${id}/analytics`} variant="secondary" size="sm">
              <Icon name="chart" size={16} /> {t("Analytics")}
            </Button>
            {canSubmit && (
              <Button size="sm" onClick={() => setSubmitting(true)}>
                <Icon name="upload" size={16} /> {t("Send for review")}
              </Button>
            )}
          </>
        }
      />
      {loading && !data ? (
        <div className="grid gap-4 lg:grid-cols-[1fr_320px]">
          <Skeleton className="h-[520px] rounded-2xl" />
          <Skeleton className="h-[520px] rounded-2xl" />
        </div>
      ) : error && !data ? (
        <ApiDownState action={<Button onClick={reload}>{t("Retry")}</Button>} />
      ) : data ? (
        <div className="flex flex-col gap-4">
          <Card>
            <div className="flex flex-wrap items-center gap-3">
              <ReviewStatusPill status={data.review_status} />
              <LiveFlags drama={data} />
              {data.submitted_at && <span className="text-xs text-text-dim">{t("Sent {date}", { date: formatDate(data.submitted_at, true) })}</span>}
              {data.reviewed_at && <span className="text-xs text-text-dim">{t("Reviewed {date}", { date: formatDate(data.reviewed_at, true) })}</span>}
            </div>
            {data.review_status === "changes_requested" && data.review_notes && (
              <Notice tone="warning" title="AFRIVA asked for changes" className="mt-4">
                <p className="whitespace-pre-line">{data.review_notes}</p>
                <p className="mt-2 text-xs">{t("Fix the series or episodes, then send it for review again.")}</p>
              </Notice>
            )}
            {data.review_status === "rejected" && (
              <Notice tone="danger" title="This series was rejected" className="mt-4">
                {data.review_notes ? <p className="whitespace-pre-line">{data.review_notes}</p> : null}
              </Notice>
            )}
            {data.review_status === "approved" && pendingEpisodes > 0 && (
              <Notice tone="info" className="mt-4">
                {t("{n} new episodes are not yet sent for review.", { n: pendingEpisodes })}
              </Notice>
            )}
            {["submitted", "in_review"].includes(data.review_status ?? "") && (
              <Notice tone="info" icon="clock" className="mt-4">
                {t("AFRIVA is reviewing this series. You'll be able to edit it again if changes are requested.")}
              </Notice>
            )}
          </Card>

          <DramaForm key={`${data.id}-${data.review_status}`} drama={data} readOnly={!editable} onSaved={(d) => mutate((prev) => (prev ? { ...prev, ...d } : prev))} />

          <Card title={t("Review history")}>
            <ReviewTimeline reviews={data.reviews ?? []} />
          </Card>

          <SubmitDialog drama={data} open={submitting} onClose={() => setSubmitting(false)} onSubmitted={(d) => mutate(() => d)} />
        </div>
      ) : null}
    </>
  );
}
