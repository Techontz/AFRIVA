import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { DramaButtons, DramaEpisodes, DramaPersonalProvider } from "@/components/site/DramaActions";
import { DramaSection } from "@/components/site/DramaRow";
import { PosterBadge } from "@/components/site/PosterCard";
import { ApiDownState } from "@/components/ui/Feedback";
import { Icon } from "@/components/ui/Icon";
import { formatCompact } from "@/lib/format";
import { serverGetWithStatus } from "@/lib/server-api";
import type { DramaDetail } from "@/lib/types";

async function loadDrama(slug: string) {
  return serverGetWithStatus<DramaDetail>(`/dramas/${encodeURIComponent(slug)}`);
}

export async function generateMetadata({ params }: PageProps<"/drama/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  const { data } = await loadDrama(slug);
  if (!data) return { title: "Drama" };
  return {
    title: data.title,
    description: data.synopsis?.slice(0, 160),
    openGraph: { title: data.title, description: data.synopsis?.slice(0, 160), images: data.backdrop_url ? [data.backdrop_url] : [] },
  };
}

export default function DramaPage({ params }: PageProps<"/drama/[slug]">) {
  return (
    <Suspense fallback={<DramaSkeleton />}>
      <DramaContent params={params} />
    </Suspense>
  );
}

async function DramaContent({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { data: drama, status } = await loadDrama(slug);
  if (status === 404) notFound();
  if (!drama) {
    return (
      <div className="site-container pt-12">
        <ApiDownState />
      </div>
    );
  }
  const genres = (drama.categories ?? []).map((c) => c.name);
  const tags = (drama.tags ?? []).filter((t) => !genres.includes(t));

  return (
    <DramaPersonalProvider drama={drama}>
      <div className="site-container pt-6">
        <nav className="mb-6 flex items-center gap-1 text-xs text-text-dim" aria-label="Breadcrumb">
          <Link href="/" className="hover:text-text">Home</Link>
          <Icon name="chevron-right" size={14} />
          <Link href="/browse" className="hover:text-text">Browse</Link>
          <Icon name="chevron-right" size={14} />
          <span className="truncate text-text-muted">{drama.title}</span>
        </nav>

        <div className="flex gap-4 sm:gap-8">
          <div className="relative aspect-[3/4] w-[120px] shrink-0 self-start overflow-hidden rounded-[8px] bg-surface ring-1 ring-black/5 sm:w-56 lg:w-64">
            <PosterBadge badge={drama.badge} />
            {drama.poster_url && <Image src={drama.poster_url} alt={drama.title} fill priority sizes="256px" className="object-cover" />}
          </div>

          <div className="min-w-0 flex-1">
            <h1 className="text-xl font-extrabold leading-tight tracking-tight sm:text-4xl">{drama.title}</h1>
            <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-[13px] text-text-muted sm:mt-3 sm:text-sm">
              <span>{drama.total_episodes} Episodes</span>
              <span className="flex items-center gap-1">
                <Icon name="eye" size={15} /> {formatCompact(drama.views)} views
              </span>
              {drama.company && <span className="hidden sm:inline">{drama.company.name}</span>}
            </div>
            {genres.length + tags.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-1.5">
                {genres.map((t) => (
                  <span key={t} className="rounded bg-surface-2 px-2 py-0.5 text-xs font-semibold text-text">
                    {t}
                  </span>
                ))}
                {tags.map((t) => (
                  <span key={t} className="rounded bg-surface-2 px-2 py-0.5 text-xs font-medium text-text-muted">
                    #{t}
                  </span>
                ))}
              </div>
            )}
            <p className="mt-4 hidden max-w-3xl text-[15px] leading-relaxed text-text-muted sm:block">{drama.synopsis}</p>
            <div className="hidden sm:block">
              <DramaButtons />
            </div>
          </div>
        </div>

        <p className="mt-4 text-sm leading-relaxed text-text-muted sm:hidden">{drama.synopsis}</p>
        <div className="sm:hidden">
          <DramaButtons />
        </div>

        <div className="mt-10 border-t border-border pt-8">
          <DramaEpisodes />
        </div>

        {drama.related?.length > 0 && (
          <div className="mt-14">
            <DramaSection title="You may also like" icon="sparkles" dramas={drama.related} />
          </div>
        )}
      </div>
    </DramaPersonalProvider>
  );
}

function DramaSkeleton() {
  return (
    <div className="site-container pt-12">
      <div className="flex flex-col gap-6 sm:flex-row sm:gap-10">
        <div className="skeleton aspect-[3/4] w-40 rounded-xl sm:w-56 lg:w-64" />
        <div className="flex-1 space-y-4 pt-2">
          <div className="skeleton h-10 w-2/3 rounded" />
          <div className="skeleton h-4 w-1/3 rounded" />
          <div className="skeleton h-4 w-full max-w-2xl rounded" />
          <div className="skeleton h-4 w-5/6 max-w-xl rounded" />
          <div className="flex gap-3 pt-4">
            <div className="skeleton h-12 w-36 rounded-full" />
            <div className="skeleton h-12 w-32 rounded-full" />
          </div>
          <div className="grid grid-cols-5 gap-2 pt-8 sm:grid-cols-10">
            {Array.from({ length: 20 }).map((_, i) => (
              <div key={i} className="skeleton aspect-square rounded-lg" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
