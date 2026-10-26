"use client";

import { useState } from "react";
import { toast } from "sonner";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useT } from "@/lib/i18n";
import type { ManagedDrama } from "@/lib/types";
import { Notice } from "../portal/ScopeKit";
import { Button } from "../ui/Button";
import { Checkbox } from "../ui/Form";
import { Modal } from "../ui/Modal";
import { useAgreement } from "./StudioNotice";

/**
 * "Tuma kwa ukaguzi": sends a series (or new episodes of an approved series) for review,
 * with the rights declaration (scope §04 "Usalama wa maudhui").
 */
export function SubmitDialog({
  drama,
  open,
  onClose,
  onSubmitted,
}: {
  drama: ManagedDrama;
  open: boolean;
  onClose: () => void;
  onSubmitted: (d: ManagedDrama) => void;
}) {
  const t = useT();
  const agreement = useAgreement();
  const [declared, setDeclared] = useState(false);
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);

  const pending = drama.episodes.filter((e) => e.review_status === "draft" || e.review_status === "changes_requested");
  const newEpisodesOnly = drama.review_status === "approved";
  const blocked =
    agreement.data?.company_status !== "active" ? "pending" : !agreement.data?.accepted ? "agreement" : null;

  const submit = async () => {
    setBusy(true);
    setErrors([]);
    try {
      const updated = await api.post<ManagedDrama>(`/studio/dramas/${drama.id}/submit`, { rights_declaration: declared });
      toast.success(t("Sent for review. We'll let you know the outcome."));
      onSubmitted(updated);
      onClose();
    } catch (e) {
      if (e instanceof ApiError && e.errors) setErrors(Object.values(e.errors).flat());
      else setErrors([errorMessage(e)]);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title="Send for review">
      <div className="flex flex-col gap-4 text-sm">
        <p className="text-text-muted">
          {newEpisodesOnly
            ? t("{n} new episodes will be sent for review. The series stays live while they are checked.", { n: pending.length })
            : t("“{title}” and {n} episodes will be sent to AFRIVA for review.", { title: drama.title, n: pending.length })}
        </p>
        <Notice tone="info" icon="info">
          {t("Uploading does not mean publishing: AFRIVA checks quality, rights and playback of every video, then approves and sets the publishing date, price and free episodes.")}
        </Notice>
        {blocked === "pending" && (
          <Notice tone="warning" title="Your creator account is not approved yet">
            {t("You can send work for review once AFRIVA approves your account.")}
          </Notice>
        )}
        {blocked === "agreement" && (
          <Notice tone="warning" title="Accept the revenue agreement" action={<Button href="/studio/agreement" size="sm">{t("Open")}</Button>}>
            {t("You must accept the creator revenue agreement before sending work for review.")}
          </Notice>
        )}
        <div className="rounded-2xl border border-border bg-surface-2/50 p-4">
          <p className="mb-2 font-bold">{t("Ownership and rights declaration")}</p>
          <Checkbox
            checked={declared}
            onChange={setDeclared}
            label={t("I confirm that I own or have licensed all rights to this content (video, music, images and trailer) and that it does not infringe anyone else's rights.")}
          />
        </div>
        {errors.length > 0 && (
          <ul className="list-disc space-y-1 rounded-xl border border-danger/30 bg-danger/10 py-3 pl-8 pr-3 text-xs text-danger">
            {errors.map((m) => (
              <li key={m}>{m}</li>
            ))}
          </ul>
        )}
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>
            {t("Cancel")}
          </Button>
          <Button onClick={submit} loading={busy} disabled={!declared || !!blocked || !pending.length}>
            {t("Send for review")}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
