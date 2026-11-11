import type { Metadata } from "next";
import { StudioApplyForm } from "@/components/site/StudioApplyForm";
import { getDict } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getDict()).site.meta.apply };
}

export default function Page() {
  return <StudioApplyForm />;
}
