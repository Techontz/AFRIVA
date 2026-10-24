"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError, str } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Thumb, Toolbar } from "@/components/portal/Kit";
import { Button } from "@/components/ui/Button";
import { StatusPill } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea, Toggle } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { api, asArray, errorMessage } from "@/lib/api";
import { cn, formatCompact } from "@/lib/format";
import { useApi, useDebounced, useList } from "@/lib/hooks";
import type { Category, Company, Drama } from "@/lib/types";

interface Form {
  title: string;
  synopsis: string;
  poster_url: string;
  backdrop_url: string;
  free_episodes: string;
  coins_per_episode: string;
  badge: string;
  category_ids: number[];
}

export default function AdminDramasPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [company, setCompany] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { items, meta, loading, error, reload, setItems } = useList<Drama>("/admin/dramas", {
    search: q,
    status,
    company_id: company,
    page,
  });
  const companies = useApi<unknown>("/admin/companies", { per_page: 100 });
  const categories = useApi<unknown>("/admin/categories");
  const companyList = asArray<Company>(companies.data);
  const categoryList = asArray<Category>(categories.data);

  const [editing, setEditing] = useState<Drama | null>(null);
  const [form, setForm] = useState<Form | null>(null);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Drama | null>(null);
  const [busy, setBusy] = useState(false);

  const patch = async (d: Drama, body: Partial<Drama>, msg: string) => {
    const prev = d;
    setItems((list) => list.map((x) => (x.id === d.id ? { ...x, ...body } : x)));
    try {
      await api.put(`/admin/dramas/${d.id}`, body);
      toast.success(msg);
    } catch (err) {
      setItems((list) => list.map((x) => (x.id === d.id ? prev : x)));
      toast.error(errorMessage(err));
    }
  };

  const openEdit = (d: Drama) => {
    setEditing(d);
    setForm({
      title: d.title,
      synopsis: str(d.synopsis),
      poster_url: str(d.poster_url),
      backdrop_url: str(d.backdrop_url),
      free_episodes: str(d.free_episodes),
      coins_per_episode: str(d.coins_per_episode),
      badge: d.badge ?? "",
      category_ids: (d.categories ?? []).map((c) => c.id),
    });
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing || !form) return;
    setSaving(true);
    const body = {
      title: form.title,
      synopsis: form.synopsis,
      poster_url: form.poster_url,
      backdrop_url: form.backdrop_url,
      free_episodes: Number(form.free_episodes || 0),
      coins_per_episode: Number(form.coins_per_episode || 0),
      badge: form.badge || null,
      category_ids: form.category_ids,
    };
    try {
      const updated = await api.put<Drama>(`/admin/dramas/${editing.id}`, body);
      const cats = categoryList.filter((c) => form.category_ids.includes(c.id));
      setItems((list) =>
        list.map((x) =>
          x.id === editing.id ? { ...x, ...body, categories: cats, ...(updated && typeof updated === "object" ? updated : {}) } as Drama : x,
        ),
      );
      toast.success("Drama updated");
      setEditing(null);
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
      await api.del(`/admin/dramas/${deleting.id}`);
      setItems((list) => list.filter((x) => x.id !== deleting.id));
      toast.success("Drama deleted");
      setDeleting(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const set = (k: keyof Form) => (e: { target: { value: string } }) => setForm((f) => (f ? { ...f, [k]: e.target.value } : f));

  return (
    <>
      <PageHeader title="Dramas" description="Every series on the platform, across all studios." />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder="Search titles…"
        />
        <Select
          className="sm:w-40"
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(1);
          }}
          aria-label="Filter by status"
        >
          <option value="">All statuses</option>
          <option value="published">Published</option>
          <option value="draft">Draft</option>
        </Select>
        <Select
          className="sm:w-52"
          value={company}
          onChange={(e) => {
            setCompany(e.target.value);
            setPage(1);
          }}
          aria-label="Filter by company"
        >
          <option value="">All companies</option>
          {companyList.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </Select>
      </Toolbar>

      {error && !items.length ? (
        <LoadError onRetry={reload} />
      ) : (
        <>
          <DataTable
            loading={loading}
            rows={items}
            rowKey={(d) => d.id}
            columns={[
              {
                key: "title",
                header: "Drama",
                render: (d) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={d.poster_url} alt={d.title} />
                    <div className="min-w-0 max-w-[240px]">
                      <Link href={`/drama/${d.slug}`} target="_blank" className="block truncate font-semibold hover:text-primary">
                        {d.title}
                      </Link>
                      <p className="truncate text-xs text-text-dim">
                        {d.company?.name ?? "—"} · {d.total_episodes} eps
                      </p>
                    </div>
                  </div>
                ),
              },
              { key: "views", header: "Views", render: (d) => formatCompact(d.views) },
              {
                key: "badge",
                header: "Badge",
                render: (d) => (
                  <Select
                    className="h-8 w-24 py-1 text-xs"
                    value={d.badge ?? ""}
                    onChange={(e) => patch(d, { badge: (e.target.value || null) as Drama["badge"] }, "Badge updated")}
                    aria-label="Badge"
                  >
                    <option value="">None</option>
                    <option value="hot">Hot</option>
                    <option value="new">New</option>
                    <option value="vip">VIP</option>
                  </Select>
                ),
              },
              {
                key: "featured",
                header: "Featured",
                render: (d) => (
                  <Toggle
                    size="sm"
                    label="Featured"
                    checked={!!d.is_featured}
                    onChange={(v) => patch(d, { is_featured: v }, v ? "Added to home hero" : "Removed from hero")}
                  />
                ),
              },
              { key: "status", header: "Status", render: (d) => <StatusPill status={d.status ?? "published"} /> },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (d) => (
                  <div className="flex justify-end gap-1">
                    <Button
                      size="sm"
                      variant={d.status === "published" ? "ghost" : "secondary"}
                      onClick={() =>
                        patch(
                          d,
                          { status: d.status === "published" ? "draft" : "published" },
                          d.status === "published" ? "Unpublished" : "Published",
                        )
                      }
                    >
                      {d.status === "published" ? "Unpublish" : "Publish"}
                    </Button>
                    <Button size="sm" variant="ghost" href={`/admin/dramas/${d.id}/episodes`}>
                      Episodes
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => openEdit(d)}>
                      Edit
                    </Button>
                    <button
                      onClick={() => setDeleting(d)}
                      className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                      aria-label={`Delete ${d.title}`}
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

      <Modal open={!!editing && !!form} onClose={() => setEditing(null)} title={`Edit ${editing?.title ?? ""}`} size="lg">
        {form && (
          <form onSubmit={save} className="grid gap-4 sm:grid-cols-2">
            <Field label="Title" className="sm:col-span-2">
              <Input required value={form.title} onChange={set("title")} />
            </Field>
            <Field label="Synopsis" className="sm:col-span-2">
              <Textarea value={form.synopsis} onChange={set("synopsis")} rows={4} />
            </Field>
            <Field label="Poster URL (3:4)">
              <Input type="url" value={form.poster_url} onChange={set("poster_url")} />
            </Field>
            <Field label="Backdrop URL (16:9)">
              <Input type="url" value={form.backdrop_url} onChange={set("backdrop_url")} />
            </Field>
            <Field label="Free episodes">
              <Input type="number" min={0} value={form.free_episodes} onChange={set("free_episodes")} />
            </Field>
            <Field label="Coins per episode">
              <Input type="number" min={0} value={form.coins_per_episode} onChange={set("coins_per_episode")} />
            </Field>
            <Field label="Badge">
              <Select value={form.badge} onChange={set("badge")}>
                <option value="">None</option>
                <option value="hot">Hot</option>
                <option value="new">New</option>
                <option value="vip">VIP</option>
              </Select>
            </Field>
            <Field label="Categories" className="sm:col-span-2">
              <div className="flex flex-wrap gap-2">
                {categoryList.map((c) => {
                  const on = form.category_ids.includes(c.id);
                  return (
                    <button
                      type="button"
                      key={c.id}
                      onClick={() =>
                        setForm((f) =>
                          f
                            ? {
                                ...f,
                                category_ids: on ? f.category_ids.filter((x) => x !== c.id) : [...f.category_ids, c.id],
                              }
                            : f,
                        )
                      }
                      className={cn(
                        "rounded-full border px-3 py-1.5 text-xs font-semibold transition",
                        on ? "border-primary bg-primary/15 text-text" : "border-border text-text-muted hover:text-text",
                      )}
                    >
                      {c.name}
                    </button>
                  );
                })}
                {!categoryList.length && <span className="text-xs text-text-dim">No categories loaded</span>}
              </div>
            </Field>
            <div className="flex justify-end gap-2 sm:col-span-2">
              <Button type="button" variant="ghost" onClick={() => setEditing(null)}>
                Cancel
              </Button>
              <Button type="submit" loading={saving}>
                Save changes
              </Button>
            </div>
          </form>
        )}
      </Modal>

      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title="Delete drama?"
        message={
          <>
            <b className="text-text">{deleting?.title}</b> and all of its episodes will be removed permanently.
          </>
        }
        confirmLabel="Delete"
      />
    </>
  );
}
