"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { Card, DataTable, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill, StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { formatDate } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { PERMISSION_LABEL, STAFF_ROLE_LABEL } from "@/lib/portal";
import type { StaffPermission, StaffRole, User } from "@/lib/types";

const ROLES: StaffRole[] = ["owner", "editor", "reviewer", "finance"];

/** Wafanyakazi: staff accounts and roles (owner, editor, reviewer, finance). Owner only. */
export default function StaffPage() {
  const t = useT();
  const { user: me } = useAuth();
  const { data, meta, loading, error, reload, mutate } = useApi<User[]>("/admin/staff");
  const roles = ((meta as unknown as { roles?: { role: StaffRole; permissions: StaffPermission[] }[] })?.roles ?? []) as {
    role: StaffRole;
    permissions: StaffPermission[];
  }[];
  const [editing, setEditing] = useState<User | "new" | null>(null);
  const [form, setForm] = useState({ name: "", email: "", password: "", staff_role: "reviewer" as StaffRole, status: "active" });
  const [busy, setBusy] = useState(false);

  const open = (u: User | "new") => {
    setEditing(u);
    setForm(
      u === "new"
        ? { name: "", email: "", password: "", staff_role: "reviewer", status: "active" }
        : { name: u.name, email: u.email ?? "", password: "", staff_role: u.staff_role ?? "owner", status: u.status ?? "active" },
    );
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing) return;
    setBusy(true);
    try {
      if (editing === "new") {
        await api.post("/admin/staff", { name: form.name, email: form.email, password: form.password, staff_role: form.staff_role });
        toast.success(t("Staff account created"));
        reload();
      } else {
        const body: Record<string, unknown> = { name: form.name, staff_role: form.staff_role, status: form.status };
        if (form.password) body.password = form.password;
        const updated = await api.put<User>(`/admin/staff/${editing.id}`, body);
        mutate((l) => (l ?? []).map((x) => (x.id === updated.id ? updated : x)));
        toast.success(t("Staff account updated"));
      }
      setEditing(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const perms = roles.find((r) => r.role === form.staff_role)?.permissions ?? [];

  return (
    <>
      <PageHeader
        title="Staff"
        description="Who can manage AFRIVA and what each role may do. Every important action is recorded in the audit log."
        actions={
          <Button size="sm" onClick={() => open("new")}>
            <Icon name="plus" size={16} /> {t("Add staff")}
          </Button>
        }
      />
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <div className="flex flex-col gap-4">
          <DataTable
            loading={loading}
            rows={data ?? []}
            rowKey={(u) => u.id}
            columns={[
              {
                key: "n",
                header: "Name",
                render: (u) => (
                  <div>
                    <p className="font-semibold">
                      {u.name} {u.id === me?.id && <span className="text-xs text-text-dim">({t("you")})</span>}
                    </p>
                    <p className="text-xs text-text-dim">{u.email}</p>
                  </div>
                ),
              },
              { key: "r", header: "Role", render: (u) => <Pill tone="brand">{t(STAFF_ROLE_LABEL[u.staff_role ?? "owner"])}</Pill> },
              { key: "s", header: "Status", render: (u) => <StatusPill status={u.status ?? "active"} /> },
              { key: "c", header: "Since", render: (u) => formatDate(u.created_at) },
              {
                key: "x",
                header: "",
                className: "text-right",
                render: (u) => (
                  <Button size="sm" variant="ghost" onClick={() => open(u)}>
                    {t("Manage")}
                  </Button>
                ),
              },
            ]}
          />
          <Card title="What each role can do">
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {roles.map((r) => (
                <div key={r.role} className="rounded-xl border border-border p-3">
                  <p className="mb-2 font-bold">{t(STAFF_ROLE_LABEL[r.role])}</p>
                  <div className="flex flex-wrap gap-1">
                    {r.permissions.map((p) => (
                      <Pill key={p}>{t(PERMISSION_LABEL[p])}</Pill>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </Card>
        </div>
      )}
      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing === "new" ? "Add staff" : "Manage staff"}>
        <form onSubmit={save} className="flex flex-col gap-4">
          <Field label="Name">
            <Input required value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
          </Field>
          {editing === "new" && (
            <Field label="Email">
              <Input required type="email" value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} />
            </Field>
          )}
          <Field label={editing === "new" ? "Password" : "New password (optional)"} hint="At least 10 characters">
            <Input
              type="password"
              minLength={10}
              required={editing === "new"}
              autoComplete="new-password"
              value={form.password}
              onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
            />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Role">
              <Select value={form.staff_role} onChange={(e) => setForm((f) => ({ ...f, staff_role: e.target.value as StaffRole }))}>
                {ROLES.map((r) => (
                  <option key={r} value={r}>
                    {t(STAFF_ROLE_LABEL[r])}
                  </option>
                ))}
              </Select>
            </Field>
            {editing !== "new" && (
              <Field label="Status">
                <Select value={form.status} onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}>
                  <option value="active">{t("Active")}</option>
                  <option value="suspended">{t("Suspended")}</option>
                </Select>
              </Field>
            )}
          </div>
          {perms.length > 0 && (
            <div className="flex flex-wrap gap-1">
              <span className="mr-1 text-xs text-text-dim">{t("Can use:")}</span>
              {perms.map((p) => (
                <Pill key={p}>{t(PERMISSION_LABEL[p])}</Pill>
              ))}
            </div>
          )}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setEditing(null)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={busy}>
              {t("Save")}
            </Button>
          </div>
        </form>
      </Modal>
    </>
  );
}
