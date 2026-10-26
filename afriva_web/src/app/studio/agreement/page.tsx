"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Card, PageHeader } from "@/components/portal/Kit";
import { Notice } from "@/components/portal/ScopeKit";
import { STUDIO_REFRESH, useAgreement } from "@/components/studio/StudioNotice";
import { Button } from "@/components/ui/Button";
import { ApiDownState, Skeleton } from "@/components/ui/Feedback";
import { Checkbox } from "@/components/ui/Form";
import { api, errorMessage } from "@/lib/api";
import { formatDate } from "@/lib/format";
import { useT } from "@/lib/i18n";
import type { CreatorAgreement } from "@/lib/types";

/** Creator revenue agreement (scope §04 "mkataba wa mapato kabla ya kuchapisha"). */
export default function AgreementPage() {
  const t = useT();
  const { data, loading, error, reload, mutate } = useAgreement();
  const [checked, setChecked] = useState(false);
  const [busy, setBusy] = useState(false);

  const accept = async () => {
    setBusy(true);
    try {
      const res = await api.post<CreatorAgreement>("/studio/agreement", { accept: true });
      mutate(() => res);
      window.dispatchEvent(new Event(STUDIO_REFRESH));
      toast.success(t("Agreement accepted"));
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader title="Revenue agreement" description="The terms for publishing your work on AFRIVA and sharing revenue." />
      {loading && !data ? (
        <Skeleton className="h-96 max-w-3xl rounded-2xl" />
      ) : error && !data ? (
        <ApiDownState action={<Button onClick={reload}>{t("Retry")}</Button>} />
      ) : data ? (
        <div className="flex max-w-3xl flex-col gap-4">
          <Card title={t("Version {v}", { v: data.version })}>
            <div className="whitespace-pre-line text-sm leading-relaxed text-text-muted">{data.text}</div>
            <p className="mt-4 text-sm">
              {t("Your revenue share:")} <b>{Number(data.revenue_share_percent)}%</b>
            </p>
          </Card>
          {data.accepted ? (
            <Notice tone="success" title="You have accepted this agreement">
              {t("Accepted on {date}.", { date: formatDate(data.accepted_at, true) })}
            </Notice>
          ) : (
            <Card>
              {data.accepted_version && (
                <Notice tone="warning" className="mb-4">
                  {t("The agreement has changed since you last accepted it. Please read and accept the new version.")}
                </Notice>
              )}
              <Checkbox checked={checked} onChange={setChecked} label={t("I have read and accept the AFRIVA creator revenue agreement.")} />
              <div className="mt-4 flex justify-end">
                <Button onClick={accept} loading={busy} disabled={!checked}>
                  {t("Accept agreement")}
                </Button>
              </div>
            </Card>
          )}
        </div>
      ) : null}
    </>
  );
}
