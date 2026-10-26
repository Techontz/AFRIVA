"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { DramaAnalyticsView } from "@/components/portal/DramaAnalyticsView";
import { Icon } from "@/components/ui/Icon";
import { useT } from "@/lib/i18n";

export default function AdminDramaAnalyticsPage() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  return (
    <DramaAnalyticsView
      path={`/admin/analytics/dramas/${id}`}
      back={
        <Link href="/admin/analytics" className="inline-flex items-center gap-1 text-xs font-semibold text-text-muted hover:text-text">
          <Icon name="chevron-left" size={14} /> {t("Analytics")}
        </Link>
      }
    />
  );
}
