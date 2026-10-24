import Link from "next/link";
import { Icon } from "../ui/Icon";
import { Logo } from "../ui/Logo";

type FooterLink = { href: string; label: string; external?: boolean };

const COLUMNS: { title: string; links: FooterLink[] }[] = [
  {
    title: "About",
    links: [
      { href: "/info/terms", label: "Terms of Use" },
      { href: "/info/privacy", label: "Privacy Policy" },
      { href: "/info/cookies", label: "Cookie Policy" },
      { href: "/info/do-not-sell", label: "Do Not Sell or Share My Info" },
    ],
  },
  {
    title: "Contact Us",
    links: [
      { href: "/info/business", label: "Business" },
      { href: "/info/media", label: "Media & PR" },
    ],
  },
  {
    title: "Join Us",
    links: [{ href: "/info/careers", label: "Careers" }],
  },
  {
    title: "Community",
    links: [
      { href: "https://facebook.com", label: "Facebook", external: true },
      { href: "https://youtube.com", label: "YouTube", external: true },
      { href: "https://tiktok.com", label: "TikTok", external: true },
      { href: "https://instagram.com", label: "Instagram", external: true },
    ],
  },
];

const COPYRIGHT_YEAR = 2026;

export function Footer() {
  return (
    <footer className="chrome-dark mt-20 bg-bg pb-safe">
      <div className="site-container py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-[1.2fr_repeat(4,1fr)]">
          <div className="col-span-2 md:col-span-1">
            <Logo size={24} />
            <p className="mt-3 max-w-xs text-sm text-text-dim">Short African dramas. One episode at a time.</p>
          </div>
          {COLUMNS.map((col) => (
            <div key={col.title}>
              <h3 className="text-sm font-bold text-text">{col.title}</h3>
              <ul className="mt-4 space-y-2.5">
                {col.links.map((l) => (
                  <li key={l.label}>
                    {l.external ? (
                      <a href={l.href} target="_blank" rel="noopener noreferrer" className="text-sm text-text-muted transition hover:text-white">
                        {l.label}
                      </a>
                    ) : (
                      <Link href={l.href} className="text-sm text-text-muted transition hover:text-white">
                        {l.label}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-10 flex flex-col gap-2 border-t border-border pt-6 text-xs text-text-dim sm:flex-row sm:items-center sm:justify-between">
          <a href="mailto:support@afriva.com" className="inline-flex items-center gap-2 transition hover:text-text">
            <Icon name="mail" size={15} /> support@afriva.com
          </a>
          <p>© {COPYRIGHT_YEAR} Afriva. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
