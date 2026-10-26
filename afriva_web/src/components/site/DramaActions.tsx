"use client";

import { useRouter } from "next/navigation";
import { createContext, useContext, useEffect, useState } from "react";
import { toast } from "sonner";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { DramaDetail, Episode, ReportReason } from "@/lib/types";
import { Button, buttonClass } from "../ui/Button";
import { Field, Select, Textarea, Input } from "../ui/Form";
import { Icon } from "../ui/Icon";
import { Modal } from "../ui/Modal";
import Link from "next/link";
import { EpisodeGrid } from "./EpisodeGrid";
import { SourceVideo, sourceFromUrl } from "./VideoSource";

interface Personal {
  drama: DramaDetail;
  episodes: Episode[];
  isFavorite: boolean;
  favBusy: boolean;
  toggleFavorite: () => void;
}

const Ctx = createContext<Personal | null>(null);

/**
 * Personalised parts of the drama page: My List state and per-user unlock state
 * (refetched with the auth token). Consumed by <DramaButtons/> and <DramaEpisodes/>.
 */
export function DramaPersonalProvider({ drama, children }: { drama: DramaDetail; children: React.ReactNode }) {
  const { user } = useAuth();
  const t = useT();
  const router = useRouter();
  const [personal, setPersonal] = useState<{ episodes: Episode[]; is_favorite: boolean } | null>(null);
  const [favBusy, setFavBusy] = useState(false);

  useEffect(() => {
    if (!user) return;
    let alive = true;
    api
      .get<DramaDetail>(`/dramas/${drama.slug}`)
      .then((d) => alive && setPersonal({ episodes: d.episodes ?? [], is_favorite: !!d.is_favorite }))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [user, drama.slug]);

  const episodes = (user && personal?.episodes) || drama.episodes || [];
  const isFavorite = user ? (personal?.is_favorite ?? drama.is_favorite) : false;

  const toggleFavorite = async () => {
    if (!user) {
      router.push(`/login?next=/drama/${drama.slug}`);
      return;
    }
    setFavBusy(true);
    const next = !isFavorite;
    setPersonal((p) => ({ episodes: p?.episodes ?? episodes, is_favorite: next }));
    try {
      await api.post(`/me/favorites/${drama.id}`);
      toast.success(next ? t("Added to My List") : t("Removed from My List"));
    } catch (e) {
      setPersonal((p) => ({ episodes: p?.episodes ?? episodes, is_favorite: !next }));
      toast.error(errorMessage(e));
    } finally {
      setFavBusy(false);
    }
  };

  return <Ctx.Provider value={{ drama, episodes, isFavorite, favBusy, toggleFavorite }}>{children}</Ctx.Provider>;
}

/** Makes it clear before tapping which episodes are free and what the rest cost (scope §02). */
function FreePreviewBanner({ drama }: { drama: DramaDetail }) {
  const t = useT();
  const free = drama.free_episodes;
  const rest =
    drama.access_mode === "vip_only"
      ? t("the rest are for VIP members only")
      : drama.access_mode === "coins_only"
        ? t("the rest unlock with {n} coins each or an episode pack", { n: drama.coins_per_episode })
        : t("the rest unlock with {n} coins each or VIP", { n: drama.coins_per_episode });
  return (
    <p className="mb-4 flex flex-wrap items-center gap-2 rounded-xl border border-success/30 bg-success/10 px-3 py-2 text-sm">
      <Icon name="play" size={14} className="text-success" />
      <span className="font-bold text-success">
        {free > 0 ? t("Episodes 1-{n} are free", { n: free }) : t("No free episodes")}
      </span>
      {drama.total_episodes > free && <span className="text-text-muted">· {rest}</span>}
    </p>
  );
}

function usePersonal() {
  const v = useContext(Ctx);
  if (!v) throw new Error("Wrap in <DramaPersonalProvider>");
  return v;
}

export function DramaButtons() {
  const { drama, isFavorite, favBusy, toggleFavorite } = usePersonal();
  const t = useT();
  const share = async () => {
    const url = window.location.href;
    try {
      if (navigator.share) await navigator.share({ title: drama.title, url });
      else {
        await navigator.clipboard.writeText(url);
        toast.success(t("Link copied"));
      }
    } catch {
      /* dismissed */
    }
  };
  return (
    <div className="mt-6 flex flex-wrap gap-3">
      <Link href={`/drama/${drama.slug}/ep/1`} className={buttonClass("primary", "lg")}>
        <Icon name="play" size={16} /> {t("Play")}
      </Link>
      {drama.trailer_url && <TrailerButton title={drama.title} url={drama.trailer_url} />}
      <button
        onClick={toggleFavorite}
        disabled={favBusy}
        aria-pressed={isFavorite}
        className={cn(buttonClass("secondary", "lg"), isFavorite && "text-primary")}
      >
        <Icon name={isFavorite ? "bookmark-filled" : "bookmark"} size={18} />
        {isFavorite ? t("In My List") : t("Add to My List")}
      </button>
      <button onClick={share} className={buttonClass("secondary", "lg", "w-12 px-0!")} aria-label={t("Share")}>
        <Icon name="share" size={18} />
      </button>
      <ReportButton dramaId={drama.id} episodes={drama.episodes ?? []} />
    </div>
  );
}

function TrailerButton({ title, url }: { title: string; url: string }) {
  const t = useT();
  const [open, setOpen] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)} className={buttonClass("secondary", "lg")}>
        <Icon name="film" size={18} /> {t("Trailer")}
      </button>
      <Modal open={open} onClose={() => setOpen(false)} title={t("Trailer: {title}", { title })} size="lg">
        <div className="chrome-dark overflow-hidden rounded-2xl bg-black">
          <SourceVideo source={sourceFromUrl(url)} className="max-h-[70dvh] w-full bg-black" controls autoPlay playsInline controlsList="nodownload" />
        </div>
      </Modal>
    </>
  );
}

const REPORT_REASONS: { value: ReportReason; label: string }[] = [
  { value: "copyright", label: "Copyright infringement" },
  { value: "inappropriate", label: "Inappropriate content" },
  { value: "misleading", label: "Misleading information" },
  { value: "other", label: "Other problem" },
];

/** "Ripoti ukiukaji": viewers report copyright or content problems (scope §04). */
function ReportButton({ dramaId, episodes }: { dramaId: number; episodes: Episode[] }) {
  const t = useT();
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState<ReportReason>("copyright");
  const [episodeId, setEpisodeId] = useState("");
  const [details, setDetails] = useState("");
  const [contact, setContact] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (reason === "copyright" && !details.trim()) {
      setError(t("Describe the work and why you own the rights."));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const res = await api.post<{ message?: string }>(`/dramas/${dramaId}/report`, {
        reason,
        details: details.trim() || null,
        episode_id: episodeId ? Number(episodeId) : null,
        contact: contact.trim() || user?.email || user?.phone || null,
      });
      toast.success(res?.message ?? t("Thank you. Your report has been received."));
      setOpen(false);
      setDetails("");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <button onClick={() => setOpen(true)} className={buttonClass("ghost", "lg")}>
        <Icon name="alert" size={18} /> {t("Report")}
      </button>
      <Modal open={open} onClose={() => setOpen(false)} title={t("Report this series")}>
        <form onSubmit={submit} className="space-y-4">
          <p className="text-sm text-text-muted">{t("Tell the AFRIVA team about copyright infringement or a problem with this content.")}</p>
          <Field label="Reason" htmlFor="report-reason">
            <Select id="report-reason" value={reason} onChange={(e) => setReason(e.target.value as ReportReason)}>
              {REPORT_REASONS.map((r) => (
                <option key={r.value} value={r.value}>
                  {t(r.label)}
                </option>
              ))}
            </Select>
          </Field>
          {episodes.length > 0 && (
            <Field label="Episode (optional)" htmlFor="report-episode">
              <Select id="report-episode" value={episodeId} onChange={(e) => setEpisodeId(e.target.value)}>
                <option value="">{t("The whole series")}</option>
                {episodes.map((ep) => (
                  <option key={ep.id} value={ep.id}>
                    {t("Episode {n}", { n: ep.number })}
                  </option>
                ))}
              </Select>
            </Field>
          )}
          <Field
            label={reason === "copyright" ? "Details (required)" : "Details"}
            htmlFor="report-details"
            hint={reason === "copyright" ? "Say which work is yours and how we can verify it." : undefined}
          >
            <Textarea id="report-details" value={details} onChange={(e) => setDetails(e.target.value)} maxLength={3000} />
          </Field>
          {!user && (
            <Field label="Your email or phone (optional)" htmlFor="report-contact">
              <Input id="report-contact" value={contact} onChange={(e) => setContact(e.target.value)} />
            </Field>
          )}
          {error && <p className="text-sm font-medium text-danger">{error}</p>}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={busy}>
              {t("Send report")}
            </Button>
          </div>
        </form>
      </Modal>
    </>
  );
}

export function DramaEpisodes() {
  const { drama, episodes } = usePersonal();
  const t = useT();
  return (
    <section id="episodes" className="scroll-mt-20">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-2">
        <h2 className="flex items-center gap-2 text-lg font-extrabold sm:text-xl">
          <Icon name="list" size={18} className="text-primary" /> {t("Episodes")}
          <span className="text-sm font-semibold text-text-dim">({drama.total_episodes})</span>
        </h2>
      </div>
      <FreePreviewBanner drama={drama} />
      <EpisodeGrid slug={drama.slug} episodes={episodes} />
    </section>
  );
}
