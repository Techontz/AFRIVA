"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { ApplicationReview } from "@/components/admin/ApplicationReview";
import { LoadError, str } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Textarea } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { api, errorMessage } from "@/lib/api";
import { initials } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import type { Company } from "@/lib/types";

interface Form {
  name: string;
  email: string;
  phone: string;
  country: string;
  revenue_share_percent: string;
  description: string;
  logo_url: string;
  owner_name: string;
  owner_email: string;
  owner_password: string;
}

const empty: Form = {
  name: "",
  email: "",
  phone: "",
  country: "TZ",
  revenue_share_percent: "",
  description: "",
  logo_url: "",
  owner_name: "",
  owner_email: "",
  owner_password: "",
};

export default function CompaniesPage() {
  const { admin, common, creator } = useT();
  const tr = admin.companies;
  const col = admin.cols;
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const [onlyApplications, setOnlyApplications] = useState(false);
  const [reviewing, setReviewing] = useState<Company | null>(null);
  const { items, meta, loading, error, reload, setItems } = useList<Company>("/admin/companies", {
    q,
    page,
    status: onlyApplications ? "pending" : undefined,
  });

  const [editing, setEditing] = useState<Company | null>(null);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<Form>(empty);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Company | null>(null);
  const [busy, setBusy] = useState(false);

  const set = (k: keyof Form) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }));

  const openCreate = () => {
    setEditing(null);
    setForm(empty);
    setOpen(true);
  };
  const openEdit = (c: Company) => {
    setEditing(c);
    setForm({
      ...empty,
      name: c.name,
      email: str(c.email),
      phone: str(c.phone),
      country: str(c.country),
      revenue_share_percent: str(c.revenue_share_percent),
      description: str(c.description),
      logo_url: str(c.logo_url),
    });
    setOpen(true);
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const body: Record<string, unknown> = {
      name: form.name,
      email: form.email || null,
      phone: form.phone || null,
      country: form.country || null,
      // Empty = follow the global creator share (Admin > Settings).
      ...(form.revenue_share_percent !== "" ? { revenue_share_percent: Number(form.revenue_share_percent) } : {}),
      description: form.description || null,
      logo_url: form.logo_url || null,
    };
    if (!editing) {
      body.owner_name = form.owner_name;
      body.owner_email = form.owner_email;
      body.owner_password = form.owner_password;
    }
    try {
      if (editing) {
        const updated = await api.put<Company>(`/admin/companies/${editing.id}`, body);
        setItems((list) => list.map((c) => (c.id === editing.id ? { ...c, ...body, ...(updated ?? {}) } as Company : c)));
        toast.success(tr.updated);
      } else {
        await api.post<Company>("/admin/companies", body);
        toast.success(tr.created);
        reload();
      }
      setOpen(false);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const toggleStatus = async (c: Company) => {
    const status = c.status === "active" ? "suspended" : "active";
    setItems((list) => list.map((x) => (x.id === c.id ? { ...x, status } : x)));
    try {
      await api.put(`/admin/companies/${c.id}`, { status });
      toast.success(fmt(c.status === "pending" ? tr.approved : status === "active" ? tr.reactivated : tr.suspended, { name: c.name }));
    } catch (err) {
      setItems((list) => list.map((x) => (x.id === c.id ? { ...x, status: c.status } : x)));
      toast.error(errorMessage(err));
    }
  };

  const remove = async () => {
    if (!deleting) return;
    setBusy(true);
    try {
      await api.del(`/admin/companies/${deleting.id}`);
      setItems((list) => list.filter((x) => x.id !== deleting.id));
      toast.success(tr.deleted);
      setDeleting(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader
        title={tr.title}
        description={tr.description}
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" size={18} /> {tr.new}
          </Button>
        }
      />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder={tr.search}
        />
        <Button
          size="sm"
          variant={onlyApplications ? "secondary" : "ghost"}
          onClick={() => {
            setOnlyApplications((v) => !v);
            setPage(1);
          }}
        >
          {creator.admin.applications}
        </Button>
      </Toolbar>

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(c) => c.id}
            columns={[
              {
                key: "name",
                header: col.company,
                render: (c) => (
                  <div className="flex items-center gap-3">
                    <div className="grid h-9 w-9 shrink-0 place-items-center overflow-hidden rounded-xl bg-surface-2 text-xs font-bold">
                      {c.logo_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={c.logo_url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        initials(c.name)
                      )}
                    </div>
                    <div className="min-w-0">
                      <Link href={`/admin/companies/${c.id}`} className="truncate font-semibold hover:text-primary">
                        {c.name}
                      </Link>
                      <p className="truncate text-xs text-text-dim">{c.email ?? c.owner?.email ?? "-"}</p>
                    </div>
                  </div>
                ),
              },
              { key: "country", header: col.country, render: (c) => c.country ?? "-" },
              { key: "share", header: col.revenueShare, render: (c) => `${Number(c.revenue_share_percent)}%` },
              { key: "dramas", header: col.dramas, render: (c) => c.dramas_count ?? "-" },
              { key: "status", header: col.status, render: (c) => <StatusPill status={c.status} /> },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (c) => (
                  <div className="flex justify-end gap-1">
                    <Button size="sm" variant="ghost" href={`/admin/companies/${c.id}`}>
                      {tr.stats}
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => openEdit(c)}>
                      {common.actions.edit}
                    </Button>
                    {c.application && c.application.status !== "approved" ? (
                      <Button size="sm" variant="secondary" onClick={() => setReviewing(c)}>
                        {creator.admin.application}
                      </Button>
                    ) : (
                      <Button size="sm" variant={c.status === "active" ? "ghost" : "secondary"} onClick={() => toggleStatus(c)}>
                        {c.status === "active" ? admin.suspend : c.status === "pending" ? admin.approve : admin.activate}
                      </Button>
                    )}
                    <button
                      onClick={() => setDeleting(c)}
                      className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                      aria-label={fmt(admin.deleteNamed, { name: c.name })}
                    >
                      <Icon name="trash" size={16} />
                    </button>
                  </div>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={editing ? fmt(admin.editNamed, { name: editing.name }) : tr.new} size="lg">
        <form onSubmit={save} className="grid gap-4 sm:grid-cols-2">
          <Field label={tr.name} className="sm:col-span-2">
            <Input required value={form.name} onChange={set("name")} placeholder="Kilima Studios" />
          </Field>
          <Field label={admin.fields.email}>
            <Input type="email" value={form.email} onChange={set("email")} />
          </Field>
          <Field label={admin.fields.phone}>
            <Input value={form.phone} onChange={set("phone")} placeholder="+255…" />
          </Field>
          <Field label={tr.country}>
            <Input value={form.country} onChange={set("country")} maxLength={2} />
          </Field>
          <Field label={tr.share} hint={tr.shareHint}>
            <Input type="number" min={0} max={100} step="0.01" value={form.revenue_share_percent} onChange={set("revenue_share_percent")} />
          </Field>
          <Field label={tr.logo} className="sm:col-span-2">
            <Input type="url" value={form.logo_url} onChange={set("logo_url")} placeholder="https://…" />
          </Field>
          <Field label={admin.fields.description} className="sm:col-span-2">
            <Textarea value={form.description} onChange={set("description")} />
          </Field>
          {!editing && (
            <div className="rounded-2xl border border-border bg-surface-2/50 p-4 sm:col-span-2">
              <p className="mb-3 flex items-center gap-2 text-sm font-bold">
                <Icon name="user" size={16} /> {tr.ownerLogin}
              </p>
              <div className="grid gap-3 sm:grid-cols-3">
                <Field label={tr.ownerName}>
                  <Input required value={form.owner_name} onChange={set("owner_name")} />
                </Field>
                <Field label={tr.ownerEmail}>
                  <Input required type="email" value={form.owner_email} onChange={set("owner_email")} />
                </Field>
                <Field label={admin.fields.password}>
                  <Input required type="password" minLength={8} value={form.owner_password} onChange={set("owner_password")} autoComplete="new-password" />
                </Field>
              </div>
            </div>
          )}
          <div className="flex justify-end gap-2 sm:col-span-2">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              {common.actions.cancel}
            </Button>
            <Button type="submit" loading={saving}>
              {editing ? admin.saveChanges : tr.create}
            </Button>
          </div>
        </form>
      </Modal>

      <ApplicationReview key={reviewing?.id ?? 0} company={reviewing} onClose={() => setReviewing(null)} onDone={reload} />

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title={tr.deleteTitle}
        message={
          <>
            {tr.deleteBefore}
            <b className="text-text">{deleting?.name}</b>
            {tr.deleteAfter}
          </>
        }
        confirmLabel={common.actions.delete}
      />
    </>
  );
}
