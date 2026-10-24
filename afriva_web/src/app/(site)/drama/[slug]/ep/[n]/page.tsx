import type { Metadata } from "next";
import { Suspense } from "react";
import { WatchPlayer } from "@/components/site/WatchPlayer";

export const metadata: Metadata = { title: "Watch" };

export default function WatchPage({ params }: PageProps<"/drama/[slug]/ep/[n]">) {
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
