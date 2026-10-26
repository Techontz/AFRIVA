"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { DramaAnalyticsView } from "@/components/portal/DramaAnalyticsView";
import { Icon } from "@/components/ui/Icon";
import { useT } from "@/lib/i18n";

export default function StudioDramaAnalyticsPage() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  return (
    <DramaAnalyticsView
      path={`/studio/dramas/${id}/analytics`}
      back={
        <Link href="/studio/analytics" className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
          <Icon name="chevron-left" size={16} /> {t("Analytics")}
        </Link>
      }
    />
  );
}
