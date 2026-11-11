import type { Metadata } from "next";
import Image from "next/image";
import { Suspense } from "react";
import { Icon } from "@/components/ui/Icon";
import { serverGet } from "@/lib/server-api";
import type { HomeData } from "@/lib/types";
import { getDict } from "@/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = (await getDict()).site.app;
  return { title: t.metaTitle, description: t.metaDescription };
}

const FEATURES = [
  { key: "vertical" },
  { key: "feed" },
  { key: "list" },
  { key: "money" },
] as const;

export default async function AppDownloadPage() {
  const t = (await getDict()).site.app;
  return (
    <div className="mx-auto grid max-w-[1120px] items-center gap-12 px-4 pt-8 sm:px-6 lg:grid-cols-[1.1fr_1fr] lg:px-8 lg:pt-16">
      <div>
        <p className="text-[13px] font-semibold text-primary">{t.badge}</p>
        <h1 className="mt-3 text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-5xl lg:text-[56px]">
          {t.headline} <span className="block text-primary">{t.headlineAccent}</span>
        </h1>
        <p className="mt-5 max-w-lg text-base leading-relaxed text-text-muted">{t.intro}</p>
        <div className="mt-8 flex flex-wrap gap-3">
          {[
            { label: "Google Play", sub: t.getItOn },
            { label: "App Store", sub: t.downloadOn },
          ].map((s) => (
            <span key={s.label} aria-disabled="true" className="rounded-[14px] bg-text/10 px-5 py-2.5 leading-tight" title={t.comingSoon}>
              <span className="block text-[11px] text-text-muted">{s.sub}</span>
              <span className="block text-[15px] font-semibold">{s.label}</span>
            </span>
          ))}
        </div>
        <p className="mt-3 text-[13px] text-text-dim">{t.storesSoon}</p>
        <ul className="mt-10 grid gap-x-8 gap-y-5 sm:grid-cols-2">
          {FEATURES.map((f) => (
            <li key={f.key}>
              <p className="flex items-center gap-2 text-[15px] font-semibold">
                <Icon name="check" size={16} className="text-primary" strokeWidth={2.4} />
                {t.features[f.key].title}
              </p>
              <p className="mt-0.5 pl-6 text-sm text-text-muted">{t.features[f.key].text}</p>
            </li>
          ))}
        </ul>
      </div>
      <div className="chrome-dark relative mx-auto aspect-[9/19] w-[250px] overflow-hidden rounded-[42px] border-[9px] border-[#1a1a1a] bg-black shadow-[0_40px_90px_-30px_rgba(0,0,0,0.8)] sm:w-[290px]">
        <Suspense fallback={<div className="skeleton absolute inset-0" />}>
          <PhoneArtwork />
        </Suspense>
      </div>
    </div>
  );
}

/** The phone shows a real title from the catalogue, the way the app opens on one. */
async function PhoneArtwork() {
  const home = await serverGet<HomeData>("/home");
  const poster = home?.banners?.[0]?.poster_url;
  if (!poster) return null;
  return (
    <>
      <Image src={poster} alt="" fill loading="eager" sizes="290px" className="object-cover" />
      <span className="absolute left-1/2 top-3 h-5 w-20 -translate-x-1/2 rounded-full bg-black" aria-hidden />
    </>
  );
}
