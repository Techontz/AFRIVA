"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, Thumb } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { EmptyState, Pill } from "@/components/ui/Feedback";
import { Field, Select, Textarea } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { cn, formatDate } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { REPORT_REASON_LABEL, type ContentReportRow } from "@/lib/portal";

const TABS = [
  ["open", "Open"],
  ["resolved", "Resolved"],
  ["dismissed", "Dismissed"],
  ["all", "All"],
] as const;

/** Ripoti: viewers' reports of copyright infringement or problem content (scope §04 "ripoti ya ukiukaji"). */
export default function ReportsPage() {
  const t = useT();
  const [tab, setTab] = useState<string>("open");
  const [page, setPage] = useState(1);
  const { data, meta, loading, error, reload, mutate } = useApi<ContentReportRow[]>("/admin/reports", { status: tab, page });
  const [handling, setHandling] = useState<ContentReportRow | null>(null);
  const [form, setForm] = useState({ status: "resolved", resolution_notes: "" });
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!handling) return;
    setBusy(true);
    try {
      const updated = await api.put<ContentReportRow>(`/admin/reports/${handling.id}`, form);
      mutate((l) => (tab === "all" ? (l ?? []).map((x) => (x.id === updated.id ? updated : x)) : (l ?? []).filter((x) => x.id !== updated.id)));
      toast.success(t("Report updated"));
      setHandling(null);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader title="Reports" description="Copyright and content reports from viewers." />
      <div className="mb-4 flex flex-wrap gap-2" role="tablist">
        {TABS.map(([k, label]) => (
          <button
            key={k}
            role="tab"
            aria-selected={tab === k}
            onClick={() => (setTab(k), setPage(1))}
            className={cn("rounded-full px-4 py-2 text-sm font-semibold transition", tab === k ? "bg-primary text-white" : "bg-surface-2 text-text-muted hover:text-text")}
          >
            {t(label)}
            {k === "open" && (meta as unknown as { open?: number })?.open ? (
              <span className="ml-2 rounded-full bg-black/25 px-1.5 text-xs">{(meta as unknown as { open: number }).open}</span>
            ) : null}
          </button>
        ))}
      </div>
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={data ?? []}
            rowKey={(r) => r.id}
            empty={<EmptyState className="border-0 bg-transparent" icon="check" title="No reports here" />}
            columns={[
              {
                key: "d",
                header: "Series",
                render: (r) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={r.drama?.poster_url} alt="" />
                    <div className="min-w-0 max-w-[220px]">
                      <Link href={r.drama ? `/admin/dramas/${r.drama.id}/episodes` : "#"} className="block truncate font-semibold hover:text-primary">
                        {r.drama?.title ?? "-"}
                      </Link>
                      {r.episode_number && <p className="text-xs text-text-dim">{t("Episode {n}", { n: r.episode_number })}</p>}
                    </div>
                  </div>
                ),
              },
              { key: "r", header: "Reason", render: (r) => <Pill tone={r.reason === "copyright" ? "danger" : "gold"}>{t(REPORT_REASON_LABEL[r.reason])}</Pill> },
              { key: "det", header: "Details", render: (r) => <p className="line-clamp-2 max-w-[280px] text-xs text-text-muted">{r.details ?? "—"}</p> },
              { key: "by", header: "Reported by", render: (r) => <span className="text-xs">{r.user?.name ?? t("Guest")}{r.contact ? ` · ${r.contact}` : ""}</span> },
              { key: "at", header: "Date", render: (r) => formatDate(r.created_at, true) },
              {
                key: "s",
                header: "Status",
                render: (r) => (
                  <div className="flex flex-col items-start gap-0.5">
                    <Pill tone={r.status === "open" ? "brand" : r.status === "resolved" ? "success" : "neutral"}>{t(r.status === "open" ? "Open" : r.status === "resolved" ? "Resolved" : "Dismissed")}</Pill>
                    {r.resolved_by && <span className="text-[11px] text-text-dim">{r.resolved_by}</span>}
                  </div>
                ),
              },
              {
                key: "x",
                header: "",
                className: "text-right",
                render: (r) => (
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => {
                      setHandling(r);
                      setForm({ status: r.status === "open" ? "resolved" : r.status, resolution_notes: r.resolution_notes ?? "" });
                    }}
                  >
                    {t("Handle")}
                  </Button>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
      <Modal open={!!handling} onClose={() => setHandling(null)} title="Handle report">
        {handling && (
          <div className="flex flex-col gap-4 text-sm">
            <p className="whitespace-pre-line rounded-xl bg-surface-2 p-3 text-text-muted">{handling.details || t("No details given")}</p>
            <Field label="Outcome">
              <Select value={form.status} onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}>
                <option value="resolved">{t("Resolved (action taken)")}</option>
                <option value="dismissed">{t("Dismissed (no problem found)")}</option>
                <option value="open">{t("Open")}</option>
              </Select>
            </Field>
            <Field label="Notes">
              <Textarea rows={3} value={form.resolution_notes} onChange={(e) => setForm((f) => ({ ...f, resolution_notes: e.target.value }))} />
            </Field>
            <p className="text-xs text-text-dim">{t("To take a series down, unpublish it on Series & Episodes.")}</p>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setHandling(null)}>
                {t("Cancel")}
              </Button>
              <Button loading={busy} onClick={save}>
                {t("Save")}
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </>
  );
}
