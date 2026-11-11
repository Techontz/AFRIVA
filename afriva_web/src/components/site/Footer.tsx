import Link from "next/link";
import { Suspense } from "react";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { getDict } from "@/i18n/server";
import { serverGet } from "@/lib/server-api";
import { Icon } from "../ui/Icon";
import { Logo } from "../ui/Logo";

type FooterLink = { href: string; label: string; external?: boolean };

function columns(t: Dictionary["common"]["footer"], requestToPost: string): { title: string; links: FooterLink[] }[] {
  return [
    {
      title: t.about,
      links: [
        { href: "/info/terms", label: t.terms },
        { href: "/info/privacy", label: t.privacy },
        { href: "/info/cookies", label: t.cookies },
        { href: "/info/do-not-sell", label: t.doNotSell },
      ],
    },
    {
      title: t.contact,
      links: [
        { href: "/info/business", label: t.business },
        { href: "/info/media", label: t.media },
      ],
    },
    {
      title: t.join,
      links: [
        { href: "/info/careers", label: t.careers },
        { href: "/apply", label: requestToPost },
      ],
    },
  ];
}

const COPYRIGHT_YEAR = 2026;

const SOCIALS = [
  { key: "facebook", label: "Facebook" },
  { key: "youtube", label: "YouTube" },
  { key: "tiktok", label: "TikTok" },
  { key: "instagram", label: "Instagram" },
] as const;

/** Links the admin set in Settings. Unset ones are hidden, and the whole column when none are set. */
async function Community({ title }: { title: string }) {
  const info = await serverGet<{ social?: Partial<Record<(typeof SOCIALS)[number]["key"], string>> }>("/site-info");
  const links = SOCIALS.filter((s) => /^https?:\/\//.test(info?.social?.[s.key] ?? ""));
  if (links.length === 0) return null;
  return (
    <div>
      <h3 className="text-[13px] font-semibold text-text">{title}</h3>
      <ul className="mt-4 space-y-2.5">
        {links.map((s) => (
          <li key={s.key}>
            <a href={info?.social?.[s.key]} target="_blank" rel="noopener noreferrer" className="text-[13px] text-text-muted transition hover:text-text">
              {s.label}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

export async function Footer() {
  const dict = await getDict();
  const t = dict.common.footer;
  return (
    <footer className="mt-20 pb-safe lg:mt-28">
      <div className="site-container py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-[1.2fr_repeat(4,1fr)]">
          <div className="col-span-2 md:col-span-1">
            <Logo size={24} />
            <p className="mt-3 max-w-xs text-sm leading-relaxed text-text-dim">{t.tagline}</p>
          </div>
          {columns(t, dict.creator.requestToPost).map((col) => (
            <div key={col.title}>
              <h3 className="text-[13px] font-semibold text-text">{col.title}</h3>
              <ul className="mt-4 space-y-2.5">
                {col.links.map((l) => (
                  <li key={l.label}>
                    {l.external ? (
                      <a href={l.href} target="_blank" rel="noopener noreferrer" className="text-[13px] text-text-muted transition hover:text-text">
                        {l.label}
                      </a>
                    ) : (
                      <Link href={l.href} className="text-[13px] text-text-muted transition hover:text-text">
                        {l.label}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
          <Suspense fallback={null}>
            <Community title={t.community} />
          </Suspense>
        </div>
        <div className="mt-10 flex flex-col gap-2 pt-2 text-xs text-text-dim sm:flex-row sm:items-center sm:justify-between">
          <a href="mailto:support@afriva.co.tz" className="inline-flex items-center gap-2 transition hover:text-text">
            <Icon name="mail" size={15} /> support@afriva.co.tz
          </a>
          <p>© {COPYRIGHT_YEAR} Afriva. {t.rights}</p>
        </div>
      </div>
    </footer>
  );
}
