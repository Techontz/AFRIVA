"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill, StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatDate, formatNumber, initials } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import type { Role, User } from "@/lib/types";
import { useT } from "@/lib/i18n";

const roleTone = { super_admin: "brand", company: "info", viewer: "neutral" } as const;
const roleLabel: Record<Role, string> = { super_admin: "Staff", company: "Creator", viewer: "Viewer" };

export default function UsersPage() {
  const [search, setSearch] = useState("");
  const [role, setRole] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { items, meta, loading, error, reload, setItems } = useList<User>("/admin/users", { search: q, role, page });

  const [editing, setEditing] = useState<User | null>(null);
  const [form, setForm] = useState({ status: "active", role: "viewer" as Role, coins_adjust: "", coins_reason: "" });
  const [saving, setSaving] = useState(false);
  const t = useT();

  const openEdit = (u: User) => {
    setEditing(u);
    setForm({ status: u.status ?? "active", role: u.role, coins_adjust: "", coins_reason: "" });
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing) return;
    setSaving(true);
    const adjust = Number(form.coins_adjust || 0);
    const body: Record<string, unknown> = { status: form.status };
    // Staff roles are managed on the Staff page; here only viewer ↔ creator.
    if (editing.role !== "super_admin") body.role = form.role;
    if (adjust) {
      body.coins_adjust = adjust;
      body.coins_reason = form.coins_reason || null;
    }
    try {
      const updated = await api.put<User>(`/admin/users/${editing.id}`, body);
      setItems((list) =>
        list.map((u) =>
          u.id === editing.id
            ? {
                ...u,
                status: form.status as User["status"],
                role: form.role,
                coins: updated?.coins ?? Math.max(0, (u.coins ?? 0) + adjust),
              }
            : u,
        ),
      );
      toast.success(t("User updated"));
      setEditing(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const adjust = Number(form.coins_adjust || 0);

  return (
    <>
      <PageHeader title="Users" description="Viewers, creators and staff." />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder="Search name, email or phone…"
        />
        <Select
          className="sm:w-44"
          value={role}
          onChange={(e) => {
            setRole(e.target.value);
            setPage(1);
          }}
          aria-label={t("Filter by role")}
        >
          <option value="">{t("All roles")}</option>
          <option value="viewer">{t("Viewers")}</option>
          <option value="company">{t("Creators")}</option>
          <option value="super_admin">{t("Staff")}</option>
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(u) => u.id}
            columns={[
              {
                key: "name",
                header: "User",
                render: (u) => (
                  <div className="flex items-center gap-3">
                    <div className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-surface-2 text-xs font-bold">{initials(u.name)}</div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold">{u.name}</p>
                      <p className="truncate text-xs text-text-dim">{u.email ?? u.phone ?? "-"}</p>
                    </div>
                  </div>
                ),
              },
              {
                key: "role",
                header: "Role",
                render: (u) => (
                  <div className="flex flex-col items-start gap-0.5">
                    <Pill tone={roleTone[u.role] ?? "neutral"}>{t(roleLabel[u.role] ?? u.role)}</Pill>
                    {u.company?.name && <span className="text-[11px] text-text-dim">{u.company.name}</span>}
                  </div>
                ),
              },
              {
                key: "coins",
                header: "Coins",
                render: (u) => (
                  <span className="inline-flex items-center gap-1 text-primary">
                    <Icon name="coin" size={14} /> {formatNumber(u.coins)}
                  </span>
                ),
              },
              {
                key: "vip",
                header: "VIP",
                render: (u) => (u.active_subscription ? <Pill tone="gold">{t(u.active_subscription.type)}</Pill> : <span className="text-text-dim">-</span>),
              },
              { key: "status", header: "Status", render: (u) => <StatusPill status={u.status ?? "active"} /> },
              { key: "joined", header: "Joined", render: (u) => formatDate(u.created_at) },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (u) => (
                  <Button size="sm" variant="ghost" onClick={() => openEdit(u)}>
                    {t("Manage")}
                  </Button>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}

      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.name ?? "User"}>
        {editing && (
          <form onSubmit={save} className="flex flex-col gap-4">
            <p className="text-sm text-text-muted">{editing.email ?? editing.phone}</p>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Status">
                <Select value={form.status} onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}>
                  <option value="active">{t("Active")}</option>
                  <option value="suspended">{t("Suspended")}</option>
                </Select>
              </Field>
              <Field label="Role">
                <Select
                  value={form.role}
                  disabled={editing.role === "super_admin"}
                  onChange={(e) => setForm((f) => ({ ...f, role: e.target.value as Role }))}
                >
                  <option value="viewer">{t("Viewer")}</option>
                  <option value="company">{t("Creator")}</option>
                  {editing.role === "super_admin" && <option value="super_admin">{t("Staff")}</option>}
                </Select>
              </Field>
            </div>
            <Field
              label="Adjust coins"
              hint={t("Current balance {from} → {to}. Use a negative number to deduct.", { from: formatNumber(editing.coins), to: formatNumber(Math.max(0, editing.coins + adjust)) })}
            >
              <Input
                type="number"
                value={form.coins_adjust}
                onChange={(e) => setForm((f) => ({ ...f, coins_adjust: e.target.value }))}
                placeholder={t("e.g. 100 or -50")}
              />
            </Field>
            {adjust !== 0 && (
              <Field label="Reason" hint="Saved in the coin ledger and audit log">
                <Input value={form.coins_reason} onChange={(e) => setForm((f) => ({ ...f, coins_reason: e.target.value }))} placeholder={t("e.g. Compensation for a failed payment")} />
              </Field>
            )}
            <div className="flex justify-end gap-2">
              <Button type="button" variant="ghost" onClick={() => setEditing(null)}>
                {t("Cancel")}
              </Button>
              <Button type="submit" loading={saving}>
                {t("Save")}
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </>
  );
}
