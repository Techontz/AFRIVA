import type { Metadata } from "next";
import { Icon } from "@/components/ui/Icon";
import { LogoMark } from "@/components/ui/Logo";

export const metadata: Metadata = { title: "Get the app", description: "Watch Afriva dramas on your phone — swipe through episodes, full-screen and vertical." };

const FEATURES = [
  { icon: "play", title: "Full-screen vertical", text: "Made for one-handed, swipe-up watching." },
  { icon: "sparkles", title: "For You feed", text: "A new first episode every swipe." },
  { icon: "bookmark", title: "Synced My List", text: "Pick up on the web where you left off." },
  { icon: "phone", title: "Mobile money ready", text: "Go VIP with M-Pesa, Mixx, Airtel and more." },
] as const;

export default function AppDownloadPage() {
  return (
    <div className="mx-auto grid max-w-[1200px] items-center gap-12 px-4 pt-12 sm:px-6 lg:grid-cols-2 lg:px-8 lg:pt-20">
      <div>
        <span className="inline-flex items-center gap-2 rounded-full bg-surface-2 px-3 py-1 text-xs font-bold text-text-muted">
          <Icon name="download" size={14} /> Afriva for Android & iOS
        </span>
        <h1 className="mt-4 text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-5xl">
          Your next episode, <span className="text-primary">in your pocket.</span>
        </h1>
        <p className="mt-4 max-w-lg text-[15px] text-text-muted">
          The Afriva app is built for vertical drama: swipe between episodes, binge the For You feed and unlock with a tap.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          {[
            { label: "Google Play", sub: "Get it on" },
            { label: "App Store", sub: "Download on the" },
          ].map((s) => (
            <span
              key={s.label}
              className="flex cursor-not-allowed items-center gap-3 rounded-2xl border border-border bg-surface px-5 py-3 opacity-90"
              title="Coming soon"
            >
              <Icon name="phone" size={26} />
              <span className="leading-tight">
                <span className="block text-[10px] uppercase tracking-wider text-text-dim">{s.sub}</span>
                <span className="block font-bold">{s.label}</span>
              </span>
            </span>
          ))}
        </div>
        <p className="mt-3 text-xs text-text-dim">Store listings are coming soon.</p>
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          {FEATURES.map((f) => (
            <div key={f.title} className="flex gap-3">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary/15 text-primary">
                <Icon name={f.icon} size={19} />
              </span>
              <div>
                <p className="font-bold">{f.title}</p>
                <p className="text-sm text-text-muted">{f.text}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="relative mx-auto aspect-[9/19] w-[260px] rounded-[44px] border-[10px] border-[#1A1A1A] chrome-dark bg-gradient-to-b from-[#2A0308] via-black to-black sm:w-[300px]">
        <div className="absolute left-1/2 top-2 h-5 w-24 -translate-x-1/2 rounded-full bg-[#1A1A1A]" />
        <div className="flex h-full flex-col items-center justify-center gap-4 p-6 text-center">
          <LogoMark size={64} />
          <p className="text-2xl font-extrabold tracking-tight">
            <span className="text-primary">A</span>FRIVA
          </p>
          <p className="text-sm text-text-muted">Short dramas. Big feelings.</p>
        </div>
      </div>
    </div>
  );
}
