import type { Metadata } from "next";
import { Suspense } from "react";
import { WatchPlayer } from "@/components/site/WatchPlayer";
import { fmt } from "@/i18n/format";
import { getDict } from "@/i18n/server";
import { serverGet } from "@/lib/server-api";
import type { DramaDetail } from "@/lib/types";

export async function generateMetadata({ params }: PageProps<"/[lang]/drama/[slug]/ep/[n]">): Promise<Metadata> {
  const { slug, n } = await params;
  const number = Math.max(1, parseInt(n, 10) || 1);
  const [drama, t] = await Promise.all([serverGet<DramaDetail>(`/dramas/${encodeURIComponent(slug)}`), getDict()]);
  if (!drama) return { title: t.site.meta.watch };
  const title = fmt(t.site.meta.watchTitle, { title: drama.title, n: number });
  const description = drama.synopsis?.slice(0, 160);
  return {
    title,
    description,
    openGraph: { title, description, images: drama.backdrop_url ? [drama.backdrop_url] : [] },
  };
}

export default function WatchPage({ params }: PageProps<"/[lang]/drama/[slug]/ep/[n]">) {
  return (
    <Suspense fallback={<div className="skeleton mx-auto mt-6 aspect-[9/16] h-[70vh] rounded-2xl" />}>
      <Watch params={params} />
    </Suspense>
  );
}

async function Watch({ params }: { params: Promise<{ slug: string; n: string }> }) {
  const { slug, n } = await params;
  const number = Math.max(1, parseInt(n, 10) || 1);
  return <WatchPlayer key={slug} slug={slug} initialNumber={number} />;
}
