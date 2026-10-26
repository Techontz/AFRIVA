"use client";

import { useState } from "react";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { Select } from "@/components/ui/Form";
import { Modal } from "@/components/ui/Modal";
import { formatDate } from "@/lib/format";
import { useApi, useDebounced } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { STAFF_ROLE_LABEL, type AuditEntry } from "@/lib/portal";

const SUBJECTS = ["Drama", "Episode", "Payment", "Plan", "PaymentMethod", "Company", "User", "Payout", "OperatingCost", "ContentReport"];

/** Audit log (scope §05 "Roles & records"): who did what, when. */
export default function AuditLogPage() {
  const t = useT();
  const [action, setAction] = useState("");
  const [subject, setSubject] = useState("");
  const [page, setPage] = useState(1);
  const a = useDebounced(action);
  const { data, meta, loading, error, reload } = useApi<AuditEntry[]>("/admin/audit-logs", { action: a, subject_type: subject, page });
  const [open, setOpen] = useState<AuditEntry | null>(null);

  return (
    <>
      <PageHeader title="Audit log" description="Important staff actions: publishing, prices, refunds, roles and settings." />
      <Toolbar>
        <SearchBox value={action} onChange={(v) => (setAction(v), setPage(1))} placeholder="Action, e.g. drama.publish" />
        <Select className="sm:w-48" value={subject} onChange={(e) => (setSubject(e.target.value), setPage(1))} aria-label={t("Filter by type")}>
          <option value="">{t("All types")}</option>
          {SUBJECTS.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </Select>
      </Toolbar>
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={data ?? []}
            rowKey={(l) => l.id}
            onRowClick={(l) => l.changes && setOpen(l)}
            columns={[
              { key: "at", header: "When", render: (l) => <span className="whitespace-nowrap text-xs">{formatDate(l.created_at, true)}</span> },
              {
                key: "u",
                header: "Who",
                render: (l) =>
                  l.user ? (
                    <div>
                      <p className="font-semibold">{l.user.name}</p>
                      <p className="text-xs text-text-dim">{l.user.staff_role ? t(STAFF_ROLE_LABEL[l.user.staff_role]) : l.user.email}</p>
                    </div>
                  ) : (
                    <span className="text-text-dim">{t("System")}</span>
                  ),
              },
              { key: "a", header: "Action", render: (l) => <code className="rounded bg-surface-2 px-1.5 py-0.5 text-xs">{l.action}</code> },
              { key: "s", header: "Subject", render: (l) => (l.subject_type ? `${l.subject_type} #${l.subject_id}` : "—") },
              { key: "sum", header: "Summary", render: (l) => <span className="line-clamp-2 max-w-[320px] text-xs text-text-muted">{l.summary ?? "—"}</span> },
              { key: "ip", header: "IP", render: (l) => <span className="font-mono text-[11px] text-text-dim">{l.ip ?? ""}</span> },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}
      <Modal open={!!open} onClose={() => setOpen(null)} title={open?.action ?? ""} size="lg">
        <pre className="max-h-[60vh] overflow-auto rounded-xl bg-surface-2 p-3 text-xs">{JSON.stringify(open?.changes, null, 2)}</pre>
      </Modal>
    </>
  );
}
