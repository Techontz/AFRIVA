"use client";

import Link from "next/link";
import { PageHeader } from "@/components/portal/Kit";
import { DramaForm } from "@/components/studio/DramaForm";
import { Icon } from "@/components/ui/Icon";
import { useT } from "@/lib/i18n";

export default function NewDramaPage() {
  const t = useT();
  return (
    <>
      <PageHeader
        back={
          <Link href="/studio/dramas" className="inline-flex items-center gap-1 text-sm text-text-muted hover:text-text">
            <Icon name="chevron-left" size={16} /> {t("My works")}
          </Link>
        }
        title={t("Submit your work")}
        description={t("Fill in the series details, then add episodes and send it for review.")}
      />
      <DramaForm />
    </>
  );
}
