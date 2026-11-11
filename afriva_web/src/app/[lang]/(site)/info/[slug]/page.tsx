import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import en from "@/i18n/dictionaries/en/site";
import { getDict } from "@/i18n/server";

/** `press` is an alias of `media`. */
const pageKey = (slug: string) => (slug === "press" ? "media" : slug);

export function generateStaticParams() {
  return [...Object.keys(en.info), "press"].map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: PageProps<"/[lang]/info/[slug]">): Promise<Metadata> {
  const [{ slug }, t] = await Promise.all([params, getDict()]);
  return { title: t.site.info[pageKey(slug)]?.title ?? "Afriva" };
}

export default function InfoPage({ params }: PageProps<"/[lang]/info/[slug]">) {
  return (
    <Suspense fallback={<InfoSkeleton />}>
      <InfoBody params={params} />
    </Suspense>
  );
}

async function InfoBody({ params }: { params: Promise<{ slug: string }> }) {
  const [{ slug }, t] = await Promise.all([params, getDict()]);
  const page = t.site.info[pageKey(slug)];
  if (!page) notFound();
  return (
    <article className="mx-auto min-h-[60dvh] max-w-2xl px-4 pt-14 sm:px-6 lg:pt-20">
      <h1 className="text-3xl font-extrabold tracking-tight lg:text-[42px] lg:leading-[1.1]">{page.title}</h1>
      <div className="mt-8 space-y-5 text-base leading-[1.7] text-text-muted">
        {page.body.map((p) => (
          <p key={p}>{p}</p>
        ))}
      </div>
    </article>
  );
}

function InfoSkeleton() {
  return (
    <div className="mx-auto min-h-[60dvh] max-w-2xl space-y-5 px-4 pt-14 sm:px-6 lg:pt-20">
      <div className="skeleton h-10 w-2/3 rounded-lg" />
      <div className="skeleton mt-8 h-24 rounded-lg" />
      <div className="skeleton h-16 rounded-lg" />
    </div>
  );
}
