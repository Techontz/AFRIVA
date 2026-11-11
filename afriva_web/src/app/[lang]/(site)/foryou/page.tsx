import type { Metadata } from "next";
import { ForYouFeed } from "@/components/site/ForYouFeed";
import { getDict } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = (await getDict()).site.meta;
  return { title: t.forYou, description: t.forYouDescription };
}

export default function ForYouPage() {
  return <ForYouFeed />;
}
