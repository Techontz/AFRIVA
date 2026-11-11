import type { Metadata } from "next";
import { ApplicationStatus } from "@/components/site/ApplicationStatus";
import { getDict } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getDict()).creator.status.title };
}

export default function Page() {
  return <ApplicationStatus inStudio />;
}
