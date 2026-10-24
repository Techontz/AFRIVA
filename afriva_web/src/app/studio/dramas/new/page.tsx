"use client";

import Link from "next/link";
import { PageHeader } from "@/components/portal/Kit";
import { DramaForm } from "@/components/studio/DramaForm";
import { Icon } from "@/components/ui/Icon";

export default function NewDramaPage() {
  return (
    <>
      <PageHeader
        back={
          <Link href="/studio/dramas" className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> My dramas
          </Link>
        }
        title="New drama"
        description="Fill in the details. You can add episodes right after saving."
      />
      <DramaForm />
    </>
  );
}
