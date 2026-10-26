"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { LoadError } from "@/components/admin/helpers";
import { EpisodeManager } from "@/components/portal/EpisodeManager";
import { PageHeader } from "@/components/portal/Kit";
import { LiveFlags, ReviewStatusPill } from "@/components/portal/ScopeKit";
import { Skeleton } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { useAuth } from "@/lib/auth";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { hasPerm } from "@/lib/portal";
import type { ManagedDrama } from "@/lib/types";

export default function AdminEpisodesPage() {
  const t = useT();
  const { user } = useAuth();
  const { id } = useParams<{ id: string }>();
  const drama = useApi<ManagedDrama>(`/admin/dramas/${id}`);
  const d = drama.data;

  return (
    <>
      <PageHeader
        back={
          <Link href="/admin/dramas" className="inline-flex items-center gap-1 text-xs font-semibold text-text-muted hover:text-text">
            <Icon name="chevron-left" size={14} /> {t("Series & Episodes")}
          </Link>
        }
        title={d?.title ? `${d.title} · ${t("Episodes")}` : t("Episodes")}
        description={d?.company?.name}
        actions={
          d && (
            <>
              <ReviewStatusPill status={d.review_status} />
              <LiveFlags drama={d} />
            </>
          )
        }
      />
      {drama.loading && !d ? (
        <Skeleton className="h-96 rounded-2xl" />
      ) : drama.error && !d ? (
        <LoadError onRetry={drama.reload} />
      ) : d ? (
        <EpisodeManager drama={d} dramaPath={`/admin/dramas/${id}`} staff={hasPerm(user, "content")} onChanged={drama.reload} />
      ) : null}
    </>
  );
}
