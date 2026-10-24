import type { Metadata } from "next";
import { notFound } from "next/navigation";

const PAGES: Record<string, { title: string; body: string[] }> = {
  terms: {
    title: "Terms of Use",
    body: [
      "By using Afriva you agree to watch content for personal, non-commercial use only. Accounts are personal and may not be shared or resold.",
      "VIP passes give unlimited access for the period purchased and do not renew automatically. Episode packs and coins are non-refundable once used to unlock an episode.",
      "We may update these terms; continued use after an update means you accept the new terms.",
    ],
  },
  privacy: {
    title: "Privacy Policy",
    body: [
      "We collect the details you give us (name, email or phone) and what you watch, so we can save your progress and recommend dramas.",
      "Payments are processed by licensed mobile-money, card and bank partners. Afriva never stores full card numbers or PINs.",
      "You can ask us to export or delete your data at any time by writing to privacy@afriva.com.",
    ],
  },
  cookies: {
    title: "Cookie Policy",
    body: [
      "Afriva uses a small number of cookies and local storage entries to keep you signed in and to remember preferences such as autoplay.",
      "We do not use third-party advertising cookies.",
    ],
  },
  business: {
    title: "Business",
    body: [
      "Are you a studio or production house? Afriva partners with storytellers across Africa and shares revenue on every view.",
      "Write to studios@afriva.com and our partnerships team will get you set up with a Studio account.",
    ],
  },
  careers: {
    title: "Careers",
    body: ["We're a small team building the home of African short drama. Send your CV and a short note to careers@afriva.com."],
  },
  media: {
    title: "Media & PR",
    body: ["For interviews, press assets and audience statistics, contact press@afriva.com."],
  },
  press: {
    title: "Media & PR",
    body: ["For interviews, press assets and audience statistics, contact press@afriva.com."],
  },
  "do-not-sell": {
    title: "Do Not Sell or Share My Info",
    body: [
      "Afriva does not sell your personal information, and we do not share it with third parties for cross-context advertising.",
      "If you'd like to confirm this for your account, or ask us to delete your data, email privacy@afriva.com from the address on your account.",
    ],
  },
};

export function generateStaticParams() {
  return Object.keys(PAGES).map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: PageProps<"/info/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  return { title: PAGES[slug]?.title ?? "Afriva" };
}

export default async function InfoPage({ params }: PageProps<"/info/[slug]">) {
  const { slug } = await params;
  const page = PAGES[slug];
  if (!page) notFound();
  return (
    <article className="mx-auto max-w-2xl px-4 pt-12 sm:px-6">
      <h1 className="text-3xl font-extrabold tracking-tight">{page.title}</h1>
      <div className="mt-6 space-y-4 text-[15px] leading-relaxed text-text-muted">
        {page.body.map((p) => (
          <p key={p}>{p}</p>
        ))}
      </div>
    </article>
  );
}
