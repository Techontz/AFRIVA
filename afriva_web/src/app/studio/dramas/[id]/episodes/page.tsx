"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useState } from "react";
import { EpisodeManager } from "@/components/portal/EpisodeManager";
import { PageHeader } from "@/components/portal/Kit";
import { ReviewStatusPill } from "@/components/portal/ScopeKit";
import { SubmitDialog } from "@/components/studio/SubmitDialog";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Skeleton } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { isCreatorEditable } from "@/lib/portal";
import type { ManagedDrama } from "@/lib/types";

export default function EpisodesManagerPage() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  const drama = useApi<ManagedDrama>(`/studio/dramas/${id}`);
  const [submitting, setSubmitting] = useState(false);
  const d = drama.data;
  const pending = d?.episodes.filter((e) => isCreatorEditable(e.review_status)).length ?? 0;
  const canSubmit = !!d && d.review_status !== "rejected" && !["submitted", "in_review"].includes(d.review_status ?? "") && pending > 0;

  return (
    <>
      <PageHeader
        back={
          <Link href={`/studio/dramas/${id}`} className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> {d?.title ?? t("Series")}
          </Link>
        }
        title={t("Episodes")}
        description={t("Upload videos, thumbnails and subtitles. Videos are processed to 480p/720p/1080p after upload.")}
        actions={
          <>
            {d && <ReviewStatusPill status={d.review_status} />}
            {canSubmit && (
              <Button size="sm" onClick={() => setSubmitting(true)}>
                <Icon name="upload" size={16} /> {t("Send for review")}
              </Button>
            )}
          </>
        }
      />
      {drama.loading && !d ? (
        <Skeleton className="h-96 rounded-2xl" />
      ) : drama.error && !d ? (
        <ApiDownState action={<Button onClick={drama.reload}>{t("Retry")}</Button>} />
      ) : d ? (
        <>
          <EpisodeManager drama={d} dramaPath={`/studio/dramas/${id}`} onChanged={drama.reload} />
          <SubmitDialog drama={d} open={submitting} onClose={() => setSubmitting(false)} onSubmitted={(n) => drama.mutate(() => n)} />
        </>
      ) : null}
    </>
  );
}
