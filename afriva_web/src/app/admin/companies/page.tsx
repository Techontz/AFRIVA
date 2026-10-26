"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError, str } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Pill, StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { formatDate, initials } from "@/lib/format";
import { useDebounced, useList } from "@/lib/hooks";
import type { Company } from "@/lib/types";
import { useT } from "@/lib/i18n";

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
  revenue_share_percent: "70",
  description: "",
  logo_url: "",
  owner_name: "",
  owner_email: "",
  owner_password: "",
};

export default function CompaniesPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState("");
  const q = useDebounced(search);
  const { items, meta, loading, error, reload, setItems } = useList<Company>("/admin/companies", { q, status, page });

  const [editing, setEditing] = useState<Company | null>(null);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<Form>(empty);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Company | null>(null);
  const [busy, setBusy] = useState(false);
  const t = useT();

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
      revenue_share_percent: Number(form.revenue_share_percent || 70),
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
        toast.success(t("Creator updated"));
      } else {
        await api.post<Company>("/admin/companies", body);
        toast.success(t("Creator created. The owner can now log in to the Studio"));
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
    const status: Company["status"] = c.status === "active" ? "suspended" : "active";
    setItems((list) => list.map((x) => (x.id === c.id ? { ...x, status } : x)));
    try {
      await api.put(`/admin/companies/${c.id}`, { status });
      toast.success(
        status === "active"
          ? c.status === "pending"
            ? t("{name} approved. They can now send work for review", { name: c.name })
            : t("{name} reactivated", { name: c.name })
          : t("{name} suspended", { name: c.name }),
      );
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
      toast.success(t("Creator deleted"));
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
        title="Creators"
        description="Studios and individual creators. New applications from the app wait here for approval."
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" size={18} /> {t("New creator")}
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
          placeholder="Search creators…"
        />
        <Select className="sm:w-44" value={status} onChange={(e) => (setStatus(e.target.value), setPage(1))} aria-label={t("Filter by status")}>
          <option value="">{t("All statuses")}</option>
          <option value="pending">{t("Waiting for approval")}</option>
          <option value="active">{t("Active")}</option>
          <option value="suspended">{t("Suspended")}</option>
        </Select>
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
                header: "Creator",
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
              { key: "country", header: "Country", render: (c) => c.country ?? "-" },
              { key: "share", header: "Revenue share", render: (c) => `${Number(c.revenue_share_percent)}%` },
              { key: "dramas", header: "Series", render: (c) => c.dramas_count ?? "-" },
              {
                key: "agreement",
                header: "Agreement",
                render: (c) =>
                  c.agreement_accepted_at ? (
                    <span className="text-xs">
                      <Icon name="check" size={13} className="inline text-success" /> {formatDate(c.agreement_accepted_at)}
                      {c.agreement_version ? ` · v${c.agreement_version}` : ""}
                    </span>
                  ) : (
                    <Pill tone="gold">{t("Not accepted")}</Pill>
                  ),
              },
              {
                key: "status",
                header: "Status",
                render: (c) => (c.status === "pending" ? <Pill tone="info">{t("Waiting for approval")}</Pill> : <StatusPill status={c.status} />),
              },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (c) => (
                  <div className="flex justify-end gap-1">
                    <Button size="sm" variant="ghost" href={`/admin/companies/${c.id}`}>
                      {t("Stats")}
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => openEdit(c)}>
                      {t("Edit")}
                    </Button>
                    <Button size="sm" variant={c.status === "active" ? "ghost" : "primary"} onClick={() => toggleStatus(c)}>
                      {c.status === "active" ? t("Suspend") : c.status === "pending" ? t("Approve") : t("Activate")}
                    </Button>
                    <button
                      onClick={() => setDeleting(c)}
                      className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                      aria-label={t("Delete {name}", { name: c.name })}
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

      <Modal open={open} onClose={() => setOpen(false)} title={editing ? t("Edit {name}", { name: editing.name }) : "New creator"} size="lg">
        <form onSubmit={save} className="grid gap-4 sm:grid-cols-2">
          <Field label="Creator / studio name" className="sm:col-span-2">
            <Input required value={form.name} onChange={set("name")} placeholder="Kilima Studios" />
          </Field>
          <Field label="Email">
            <Input type="email" value={form.email} onChange={set("email")} />
          </Field>
          <Field label="Phone">
            <Input value={form.phone} onChange={set("phone")} placeholder="+255…" />
          </Field>
          <Field label="Country (ISO code)">
            <Input value={form.country} onChange={set("country")} maxLength={2} />
          </Field>
          <Field label="Revenue share %" hint="Creator's share of attributed revenue">
            <Input type="number" min={0} max={100} step="0.01" value={form.revenue_share_percent} onChange={set("revenue_share_percent")} />
          </Field>
          <Field label="Logo URL" className="sm:col-span-2">
            <Input type="url" value={form.logo_url} onChange={set("logo_url")} placeholder="https://…" />
          </Field>
          <Field label="Description" className="sm:col-span-2">
            <Textarea value={form.description} onChange={set("description")} />
          </Field>
          {!editing && (
            <div className="rounded-2xl border border-border bg-surface-2/50 p-4 sm:col-span-2">
              <p className="mb-3 flex items-center gap-2 text-sm font-bold">
                <Icon name="user" size={16} /> {t("Studio owner login")}
              </p>
              <div className="grid gap-3 sm:grid-cols-3">
                <Field label="Owner name">
                  <Input required value={form.owner_name} onChange={set("owner_name")} />
                </Field>
                <Field label="Owner email">
                  <Input required type="email" value={form.owner_email} onChange={set("owner_email")} />
                </Field>
                <Field label="Password">
                  <Input required type="password" minLength={8} value={form.owner_password} onChange={set("owner_password")} autoComplete="new-password" />
                </Field>
              </div>
            </div>
          )}
          <div className="flex justify-end gap-2 sm:col-span-2">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={saving}>
              {editing ? t("Save changes") : t("Create creator")}
            </Button>
          </div>
        </form>
      </Modal>

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title="Delete creator?"
        message={
          <>
            {t("This permanently removes")} <b className="text-text">{deleting?.name}</b>.{" "}
            {t("Consider suspending instead to keep its history.")}
          </>
        }
        confirmLabel="Delete"
      />
    </>
  );
}
