"use client";

import Link from "next/link";
import { PageHeader } from "@/components/portal/Kit";
import { DramaForm } from "@/components/studio/DramaForm";
import { Icon } from "@/components/ui/Icon";
import { useT } from "@/i18n/client";

export default function NewDramaPage() {
  const t = useT().studio.dramas;
  return (
    <>
      <PageHeader
        back={
          <Link href="/studio/dramas" className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> {t.back}
          </Link>
        }
        title={t.newDrama}
        description={t.newDescription}
      />
      <DramaForm />
    </>
  );
}
