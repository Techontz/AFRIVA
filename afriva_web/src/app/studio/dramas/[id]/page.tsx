"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { PageHeader } from "@/components/portal/Kit";
import { DramaForm } from "@/components/studio/DramaForm";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Skeleton } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { useApi } from "@/lib/hooks";
import type { Drama } from "@/lib/types";

export default function EditDramaPage() {
  const { id } = useParams<{ id: string }>();
  const { data, loading, error, reload } = useApi<Drama>(`/studio/dramas/${id}`);

  return (
    <>
      <PageHeader
        back={
          <Link href="/studio/dramas" className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> My dramas
          </Link>
        }
        title={data?.title ?? "Edit drama"}
        description="Update details, artwork and pricing."
        actions={
          <Button href={`/studio/dramas/${id}/episodes`} variant="secondary" size="sm">
            <Icon name="list" size={16} /> Manage episodes
          </Button>
        }
      />
      {loading && !data ? (
        <div className="grid gap-4 lg:grid-cols-[1fr_320px]">
          <Skeleton className="h-[520px] rounded-2xl" />
          <Skeleton className="h-[520px] rounded-2xl" />
        </div>
      ) : error && !data ? (
        <ApiDownState action={<Button onClick={reload}>Retry</Button>} />
      ) : data ? (
        <DramaForm key={data.id} drama={data} />
      ) : null}
    </>
  );
}
