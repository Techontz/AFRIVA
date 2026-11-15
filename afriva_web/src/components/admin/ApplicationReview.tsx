"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import { StreamVideo } from "@/components/site/StreamVideo";
import { Button } from "@/components/ui/Button";
import { Spinner } from "@/components/ui/Feedback";
import { Field, Textarea } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { useT } from "@/i18n/client";
import type { Dictionary } from "@/i18n/dictionaries/en";
import { fmt } from "@/i18n/format";
import { API_URL, api, errorMessage, getToken } from "@/lib/api";
import { type ApplicationSample, type PayoutAccount, type SamplesSummary, mmss, pct } from "@/lib/creator";
import type { Company } from "@/lib/types";

/** "M-Pesa · Asha Juma · +2557..." or "CRDB · Asha Juma · 0150..." */
export function payoutText(p: PayoutAccount | null | undefined, t: Dictionary["creator"]): string {
  if (!p?.method) return t.payout.none;
  const head = p.method === "bank" ? (p.bank_name ?? t.form.bank) : (t.form.providers[p.provider as keyof typeof t.form.providers] ?? p.provider ?? t.form.mobileMoney);
  return [head, p.account_name, p.account_number].filter(Boolean).join(" · ");
}

interface SamplesPayload {
  review_status: string;
  samples_summary: SamplesSummary;
  samples: ApplicationSample[];
}

/** Super admin review of a request to post: details, ID photo, sample videos, approve or reject with a reason. */
export function ApplicationReview({ company, onClose, onDone }: { company: Company | null; onClose: () => void; onDone: () => void }) {
  const { creator: tAll, common } = useT();
  const t = tAll.admin;
  const app = company?.application ?? null;
  const [samples, setSamples] = useState<SamplesPayload | null>(null);
  const [playing, setPlaying] = useState<ApplicationSample | null>(null);
  const [idUrl, setIdUrl] = useState<{ url: string; pdf: boolean } | null>(null);
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  // The parent remounts this component per company (key), so state starts fresh.
  useEffect(() => {
    if (!company?.application) return;
    api
      .get<SamplesPayload>(`/admin/companies/${company.id}/samples`)
      .then(setSamples)
      .catch((e) => toast.error(errorMessage(e)));
  }, [company]);

  useEffect(() => () => {
    if (idUrl?.url.startsWith("blob:")) URL.revokeObjectURL(idUrl.url);
  }, [idUrl]);

  if (!company || !app) return null;

  const viewId = async () => {
    try {
      // ?as=url: on R2 the API answers with a short-lived signed link (shown directly, no bucket CORS needed);
      // on the server's own disk it streams the file as before.
      const res = await fetch(`${API_URL}/admin/companies/${company.id}/id-document?as=url`, {
        headers: { Authorization: `Bearer ${getToken() ?? ""}`, Accept: "*/*" },
        cache: "no-store",
      });
      if (!res.ok) throw new Error(String(res.status));
      if ((res.headers.get("content-type") ?? "").includes("application/json")) {
        const { data } = (await res.json()) as { data: { url: string; pdf: boolean } };
        setIdUrl({ url: data.url, pdf: data.pdf });
        return;
      }
      const blob = await res.blob();
      setIdUrl({ url: URL.createObjectURL(blob), pdf: blob.type === "application/pdf" });
    } catch (e) {
      toast.error(errorMessage(e));
    }
  };

  const setStatus = async (status: "active" | "rejected") => {
    setBusy(true);
    try {
      await api.put(`/admin/companies/${company.id}`, status === "rejected" ? { status, rejection_reason: reason.trim() } : { status });
      toast.success(status === "active" ? t.approved : t.rejected);
      onDone();
      onClose();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  const summary = samples?.samples_summary ?? app.samples_summary;
  const ready = (samples?.review_status ?? app.review_status) === "ready_for_review";
  const pending = app.status === "pending";
  const rows: [string, React.ReactNode][] = [
    [t.fullName, app.full_name],
    [t.idType, app.id_type === "passport" ? tAll.form.passport : tAll.form.nida],
    [t.idNumber, app.id_number ?? "-"],
    [
      t.idDocument,
      app.has_id_document ? (
        <Button key="id" size="sm" variant="outline" onClick={() => void viewId()}>
          {t.viewId}
        </Button>
      ) : (
        t.noId
      ),
    ],
    [t.phone, app.phone],
    [t.email, app.email ?? "-"],
    [t.payout, payoutText(company.payout, tAll)],
    [t.accepted, app.guidelines_accepted_at ? new Date(app.guidelines_accepted_at).toLocaleString() : "-"],
    [t.share, `${pct(app.creator_share_percent)}%`],
    [t.reviewStatus, tAll.status.review[app.review_status]],
  ];
  if (app.existing_user) rows.push([t.existingUser, "✓"]);
  if (app.rejection_reason) rows.push([t.reason, app.rejection_reason]);

  return (
    <Modal open onClose={onClose} title={`${t.application}: ${company.name}`} size="xl">
      <div className="space-y-5 text-sm">
        <dl className="grid gap-x-6 gap-y-2 sm:grid-cols-2">
          {rows.map(([k, v]) => (
            <div key={k} className="flex items-center justify-between gap-3 border-b border-border py-2">
              <dt className="text-text-dim">{k}</dt>
              <dd className="text-right font-medium">{v}</dd>
            </div>
          ))}
        </dl>

        {idUrl &&
          (idUrl.pdf ? (
            <a href={idUrl.url} target="_blank" rel="noreferrer" className="font-semibold text-primary hover:underline">
              {t.viewId} (PDF)
            </a>
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={idUrl.url} alt={t.idDocument} className="max-h-80 rounded-xl border border-border object-contain" />
          ))}

        <div>
          <p className="mb-2 font-bold">
            {t.samples}
            {summary && <span className="ml-2 font-normal text-text-muted">{fmt(t.samplesProgress, { valid: summary.valid, required: summary.required, uploaded: summary.uploaded })}</span>}
          </p>
          {!samples ? (
            <Spinner />
          ) : samples.samples.length === 0 ? (
            <p className="text-text-muted">{t.noSamples}</p>
          ) : (
            <ul className="divide-y divide-border">
              {samples.samples.map((s, i) => (
                <li key={s.id} className="flex items-center gap-3 py-2">
                  <span className="w-8 text-text-dim">{i + 1}</span>
                  <span className="min-w-0 flex-1 truncate">{s.title}</span>
                  <span className="tabular-nums text-text-muted">{mmss(s.duration_seconds)}</span>
                  <span className={s.valid ? "text-text" : "text-danger"}>
                    {s.length_check === "too_short" ? tAll.status.tooShort : s.length_check === "too_long" ? tAll.status.tooLong : s.status === "ready" ? tAll.status.ready : s.status === "failed" ? tAll.status.failed : tAll.status.processing}
                  </span>
                  {s.playback_url && (
                    <Button size="sm" variant="ghost" onClick={() => setPlaying(s)}>
                      {t.play}
                    </Button>
                  )}
                </li>
              ))}
            </ul>
          )}
          {playing?.playback_url && (
            <div className="mt-3 overflow-hidden rounded-xl bg-black">
              <StreamVideo key={playing.id} src={playing.playback_url} controls autoPlay playsInline className="max-h-[60vh] w-full" />
            </div>
          )}
        </div>

        {pending && (
          <div className="space-y-3 border-t border-border pt-4">
            {rejecting ? (
              <>
                <Field label={t.rejectReason}>
                  <Textarea value={reason} maxLength={500} onChange={(e) => setReason(e.target.value)} />
                </Field>
                <div className="flex justify-end gap-2">
                  <Button variant="ghost" onClick={() => setRejecting(false)}>
                    {common.actions.cancel}
                  </Button>
                  <Button variant="danger" loading={busy} disabled={!reason.trim()} onClick={() => void setStatus("rejected")}>
                    {t.rejectConfirm}
                  </Button>
                </div>
              </>
            ) : (
              <>
                {!ready && <p className="text-xs text-text-dim">{t.approveBlocked}</p>}
                <div className="flex justify-end gap-2">
                  <Button variant="danger" onClick={() => setRejecting(true)}>
                    {t.reject}
                  </Button>
                  <Button loading={busy} disabled={!ready} onClick={() => void setStatus("active")}>
                    {t.approve}
                  </Button>
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </Modal>
  );
}
