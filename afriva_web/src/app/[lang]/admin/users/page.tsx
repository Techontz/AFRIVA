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
import { useLocale, useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { formatDate, formatNumber, initials } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import type { Role, User } from "@/lib/types";

const roleTone = { super_admin: "brand", company: "info", viewer: "neutral" } as const;

export default function UsersPage() {
  const { admin, common } = useT();
  const locale = useLocale();
  const tr = admin.users;
  const col = admin.cols;
  const roleLabel = tr.roles as Record<string, string>;
  const [search, setSearch] = useState("");
  const [role, setRole] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { items, meta, loading, error, reload, setItems } = useList<User>("/admin/users", { search: q, role, page });

  const [editing, setEditing] = useState<User | null>(null);
  const [form, setForm] = useState({ status: "active", role: "viewer" as Role, coins_adjust: "" });
  const [saving, setSaving] = useState(false);

  const openEdit = (u: User) => {
    setEditing(u);
    setForm({ status: u.status ?? "active", role: u.role, coins_adjust: "" });
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing) return;
    setSaving(true);
    const adjust = Number(form.coins_adjust || 0);
    const body: Record<string, unknown> = { status: form.status, role: form.role };
    if (adjust) body.coins_adjust = adjust;
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
      toast.success(tr.updated);
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
      <PageHeader title={admin.nav.users} description={tr.description} />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder={tr.search}
        />
        <Select
          className="sm:w-44"
          value={role}
          onChange={(e) => {
            setRole(e.target.value);
            setPage(1);
          }}
          aria-label={tr.filterRole}
        >
          <option value="">{tr.allRoles}</option>
          <option value="viewer">{tr.rolesPlural.viewer}</option>
          <option value="company">{tr.rolesPlural.company}</option>
          <option value="super_admin">{tr.rolesPlural.super_admin}</option>
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
                header: col.user,
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
                header: col.role,
                render: (u) => (
                  <div className="flex flex-col items-start gap-0.5">
                    <Pill tone={roleTone[u.role] ?? "neutral"}>{roleLabel[u.role] ?? u.role}</Pill>
                    {u.company?.name && <span className="text-[11px] text-text-dim">{u.company.name}</span>}
                  </div>
                ),
              },
              {
                key: "coins",
                header: col.coins,
                render: (u) => (
                  <span className="inline-flex items-center gap-1 text-primary">
                    <Icon name="coin" size={14} /> {formatNumber(u.coins)}
                  </span>
                ),
              },
              {
                key: "vip",
                header: "VIP",
                render: (u) => (u.active_subscription ? <Pill tone="gold">{admin.plans.typeShort[u.active_subscription.type] ?? u.active_subscription.type}</Pill> : <span className="text-text-dim">-</span>),
              },
              { key: "status", header: col.status, render: (u) => <StatusPill status={u.status ?? "active"} /> },
              { key: "joined", header: tr.joined, render: (u) => formatDate(u.created_at, false, locale) },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (u) => (
                  <Button size="sm" variant="ghost" onClick={() => openEdit(u)}>
                    {tr.manage}
                  </Button>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}

      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.name ?? col.user}>
        {editing && (
          <form onSubmit={save} className="flex flex-col gap-4">
            <p className="text-sm text-text-muted">{editing.email ?? editing.phone}</p>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label={col.status}>
                <Select value={form.status} onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}>
                  <option value="active">{common.status.active}</option>
                  <option value="suspended">{common.status.suspended}</option>
                </Select>
              </Field>
              <Field label={col.role}>
                <Select value={form.role} onChange={(e) => setForm((f) => ({ ...f, role: e.target.value as Role }))}>
                  <option value="viewer">{tr.roles.viewer}</option>
                  <option value="company">{tr.roles.company}</option>
                  <option value="super_admin">{tr.roles.super_admin}</option>
                </Select>
              </Field>
            </div>
            <Field
              label={tr.adjustCoins}
              hint={fmt(tr.adjustHint, { from: formatNumber(editing.coins), to: formatNumber(Math.max(0, editing.coins + adjust)) })}
            >
              <Input
                type="number"
                value={form.coins_adjust}
                onChange={(e) => setForm((f) => ({ ...f, coins_adjust: e.target.value }))}
                placeholder={tr.adjustPlaceholder}
              />
            </Field>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="ghost" onClick={() => setEditing(null)}>
                {common.actions.cancel}
              </Button>
              <Button type="submit" loading={saving}>
                {common.actions.save}
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </>
  );
}
