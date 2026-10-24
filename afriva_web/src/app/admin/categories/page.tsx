"use client";

import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { DataTable, PageHeader } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { Field, Input } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { useList } from "@/lib/hooks";
import type { Category } from "@/lib/types";

const slugify = (s: string) =>
  s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

export default function CategoriesPage() {
  const { items, loading, error, reload, setItems } = useList<Category>("/admin/categories");
  const cats = [...items].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
  const [editing, setEditing] = useState<Category | null>(null);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name: "", slug: "", sort_order: "0" });
  const [slugTouched, setSlugTouched] = useState(false);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Category | null>(null);
  const [busy, setBusy] = useState(false);

  const openCreate = () => {
    setEditing(null);
    setForm({ name: "", slug: "", sort_order: String(cats.length) });
    setSlugTouched(false);
    setOpen(true);
  };
  const openEdit = (c: Category) => {
    setEditing(c);
    setForm({ name: c.name, slug: c.slug, sort_order: String(c.sort_order ?? 0) });
    setSlugTouched(true);
    setOpen(true);
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const body = { name: form.name, slug: form.slug || slugify(form.name), sort_order: Number(form.sort_order || 0) };
    try {
      if (editing) {
        await api.put(`/admin/categories/${editing.id}`, body);
        setItems((list) => list.map((c) => (c.id === editing.id ? { ...c, ...body } : c)));
        toast.success("Category updated");
      } else {
        await api.post("/admin/categories", body);
        toast.success("Category created");
        reload();
      }
      setOpen(false);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const remove = async () => {
    if (!deleting) return;
    setBusy(true);
    try {
      await api.del(`/admin/categories/${deleting.id}`);
      setItems((list) => list.filter((x) => x.id !== deleting.id));
      toast.success("Category deleted");
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
        title="Categories"
        description="Genres shown as chips on Browse and as rows on Home."
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" size={18} /> New category
          </Button>
        }
      />
      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <DataTable
          loading={loading}
          rows={cats}
          rowKey={(c) => c.id}
          columns={[
            { key: "name", header: "Name", render: (c) => <span className="font-semibold">{c.name}</span> },
            { key: "slug", header: "Slug", render: (c) => <span className="font-mono text-xs text-text-muted">{c.slug}</span> },
            { key: "count", header: "Dramas", render: (c) => c.dramas_count ?? "—" },
            { key: "order", header: "Order", render: (c) => c.sort_order ?? 0 },
            {
              key: "actions",
              header: "",
              className: "text-right",
              render: (c) => (
                <div className="flex justify-end gap-1">
                  <Button size="sm" variant="ghost" onClick={() => openEdit(c)}>
                    Edit
                  </Button>
                  <button
                    onClick={() => setDeleting(c)}
                    className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                    aria-label={`Delete ${c.name}`}
                  >
                    <Icon name="trash" size={16} />
                  </button>
                </div>
              ),
            },
          ]}
        />
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={editing ? "Edit category" : "New category"} size="sm">
        <form onSubmit={save} className="flex flex-col gap-4">
          <Field label="Name">
            <Input
              required
              value={form.name}
              onChange={(e) => {
                const name = e.target.value;
                setForm((f) => ({ ...f, name, slug: slugTouched ? f.slug : slugify(name) }));
              }}
              placeholder="Village Life"
            />
          </Field>
          <Field label="Slug">
            <Input
              value={form.slug}
              onChange={(e) => {
                setSlugTouched(true);
                setForm((f) => ({ ...f, slug: slugify(e.target.value) }));
              }}
            />
          </Field>
          <Field label="Sort order">
            <Input type="number" value={form.sort_order} onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))} />
          </Field>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" loading={saving}>
              Save
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
        title="Delete category?"
        message={
          <>
            Dramas tagged <b className="text-text">{deleting?.name}</b> stay published but lose this category.
          </>
        }
        confirmLabel="Delete"
      />
    </>
  );
}
