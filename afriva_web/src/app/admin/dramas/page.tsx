"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { LoadError, str } from "@/components/admin/helpers";
import { DataTable, PageHeader, Pagination, SearchBox, Thumb, Toolbar } from "@/components/portal/Kit";
import { LiveFlags, Notice, ReviewStatusPill } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { Field, Input, Select, Textarea, Toggle } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { ConfirmModal, Modal } from "@/components/ui/Modal";
import { api, asArray, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cn, formatCompact } from "@/lib/format";
import { useApi, useDebounced, useList } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { ACCESS_MODE_LABEL, AGE_RATING_LABEL, AGE_RATINGS, hasPerm, REVIEW_LABEL, toLocalInput } from "@/lib/portal";
import type { AccessMode, AgeRating, Category, Company, Drama, ReviewStatus } from "@/lib/types";

interface Form {
  company_id: string;
  title: string;
  synopsis: string;
  poster_url: string;
  backdrop_url: string;
  trailer_url: string;
  age_rating: AgeRating | "";
  category_ids: number[];
}

interface PublishForm {
  when: "now" | "schedule";
  publish_at: string;
  free_episodes: string;
  coins_per_episode: string;
  access_mode: AccessMode;
  is_featured: boolean;
  badge: string;
}

export default function AdminDramasPage() {
  const t = useT();
  const { user } = useAuth();
  const params = useSearchParams();
  const canContent = hasPerm(user, "content");
  const canPublish = hasPerm(user, "publish");

  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [review, setReview] = useState("");
  const [company, setCompany] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounced(search);
  const { items, meta, loading, error, reload, setItems } = useList<Drama>("/admin/dramas", {
    q,
    status,
    review_status: review,
    company_id: company,
    page,
  });
  const companies = useApi<unknown>(hasPerm(user, "creators") ? "/admin/companies" : null, { per_page: 100 });
  const categories = useApi<unknown>("/categories");
  const companyList = asArray<Company>(companies.data);
  const categoryList = asArray<Category>(categories.data);

  const [editing, setEditing] = useState<Drama | "new" | null>(null);
  const [form, setForm] = useState<Form | null>(null);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<Drama | null>(null);
  const [publishing, setPublishing] = useState<Drama | null>(null);
  const [pform, setPform] = useState<PublishForm | null>(null);
  const [unpublishing, setUnpublishing] = useState<Drama | null>(null);
  const [busy, setBusy] = useState(false);

  const replace = (d: Drama) => setItems((list) => list.map((x) => (x.id === d.id ? { ...x, ...d } : x)));

  const openPublish = (d: Drama) => {
    setPublishing(d);
    setPform({
      when: d.publish_at && new Date(d.publish_at) > new Date() ? "schedule" : "now",
      publish_at: toLocalInput(d.publish_at),
      free_episodes: String(d.free_episodes ?? 8),
      coins_per_episode: String(d.coins_per_episode ?? 30),
      access_mode: d.access_mode ?? "coins_or_vip",
      is_featured: !!d.is_featured,
      badge: d.badge ?? "",
    });
  };

  // Deep link from the review page: /admin/dramas?publish=<id>
  const publishId = params.get("publish");
  useEffect(() => {
    if (!publishId) return;
    api.get<Drama>(`/admin/dramas/${publishId}`).then(openPublish).catch(() => {});
  }, [publishId]);

  const publish = async () => {
    if (!publishing || !pform) return;
    if (pform.when === "schedule" && !pform.publish_at) {
      toast.error(t("Choose the publishing date and time"));
      return;
    }
    setBusy(true);
    try {
      const updated = await api.post<Drama>(`/admin/dramas/${publishing.id}/publish`, {
        publish_at: pform.when === "schedule" ? new Date(pform.publish_at).toISOString() : null,
        free_episodes: Number(pform.free_episodes || 0),
        coins_per_episode: Number(pform.coins_per_episode || 0),
        access_mode: pform.access_mode,
        is_featured: pform.is_featured,
        badge: pform.badge || null,
      });
      replace(updated);
      toast.success(updated.is_scheduled ? t("Scheduled") : t("Published"));
      setPublishing(null);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  const unpublish = async () => {
    if (!unpublishing) return;
    setBusy(true);
    try {
      replace(await api.post<Drama>(`/admin/dramas/${unpublishing.id}/unpublish`));
      toast.success(t("Unpublished"));
      setUnpublishing(null);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  const openEdit = (d: Drama | "new") => {
    setEditing(d);
    const x = d === "new" ? null : d;
    setForm({
      company_id: x?.company?.id ? String(x.company.id) : "",
      title: x?.title ?? "",
      synopsis: str(x?.synopsis),
      poster_url: str(x?.poster_url),
      backdrop_url: str(x?.backdrop_url),
      trailer_url: x?.trailer_url && !x.trailer_url.includes("/media/videos/") ? x.trailer_url : "",
      age_rating: x?.age_rating ?? "",
      category_ids: (x?.categories ?? []).map((c) => c.id),
    });
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editing || !form) return;
    setSaving(true);
    const body: Record<string, unknown> = {
      title: form.title,
      synopsis: form.synopsis,
      poster_url: form.poster_url || null,
      backdrop_url: form.backdrop_url || null,
      age_rating: form.age_rating || null,
      category_ids: form.category_ids,
    };
    if (form.trailer_url) body.trailer_url = form.trailer_url;
    if (editing === "new") body.company_id = Number(form.company_id);
    try {
      if (editing === "new") {
        await api.post<Drama>("/admin/dramas", body);
        toast.success(t("Series created. Add episodes, then publish it."));
        reload();
      } else {
        replace(await api.put<Drama>(`/admin/dramas/${editing.id}`, body));
        toast.success(t("Series updated"));
      }
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
      toast.success(t("Series deleted"));
      setDeleting(null);
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const set = (k: keyof Form) => (e: { target: { value: string } }) => setForm((f) => (f ? { ...f, [k]: e.target.value } : f));
  const setP = <K extends keyof PublishForm>(k: K, v: PublishForm[K]) => setPform((f) => (f ? { ...f, [k]: v } : f));

  return (
    <>
      <PageHeader
        title="Series & Episodes"
        description="Every series on AFRIVA: review state, publishing rules and episodes."
        actions={
          canContent && (
            <Button size="sm" onClick={() => openEdit("new")}>
              <Icon name="plus" size={16} /> {t("Add series")}
            </Button>
          )
        }
      />
      <Toolbar>
        <SearchBox
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder="Search titles…"
        />
        <Select className="sm:w-40" value={status} onChange={(e) => (setStatus(e.target.value), setPage(1))} aria-label={t("Filter by status")}>
          <option value="">{t("Published or not")}</option>
          <option value="published">{t("Published")}</option>
          <option value="draft">{t("Not published")}</option>
        </Select>
        <Select className="sm:w-48" value={review} onChange={(e) => (setReview(e.target.value), setPage(1))} aria-label={t("Filter by review status")}>
          <option value="">{t("All review statuses")}</option>
          {(Object.keys(REVIEW_LABEL) as ReviewStatus[]).map((s) => (
            <option key={s} value={s}>
              {t(REVIEW_LABEL[s])}
            </option>
          ))}
        </Select>
        {companyList.length > 0 && (
          <Select className="sm:w-52" value={company} onChange={(e) => (setCompany(e.target.value), setPage(1))} aria-label={t("Filter by creator")}>
            <option value="">{t("All creators")}</option>
            {companyList.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </Select>
        )}
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
                header: "Series",
                render: (d) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={d.poster_url} alt={d.title} />
                    <div className="min-w-0 max-w-[240px]">
                      <Link href={`/admin/dramas/${d.id}/episodes`} className="block truncate font-semibold hover:text-primary">
                        {d.title}
                      </Link>
                      <p className="truncate text-xs text-text-dim">
                        {d.company?.name ?? "-"} · {t("{n} eps", { n: d.episodes_count ?? d.total_episodes })}
                      </p>
                    </div>
                  </div>
                ),
              },
              { key: "review", header: "Review", render: (d) => <ReviewStatusPill status={d.review_status} /> },
              { key: "live", header: "Status", render: (d) => <LiveFlags drama={d} /> },
              {
                key: "rules",
                header: "Rules",
                render: (d) => (
                  <span className="text-xs text-text-muted">
                    {t("{free} free · {coins} coins", { free: d.free_episodes, coins: d.coins_per_episode })}
                    <br />
                    {t(ACCESS_MODE_LABEL[d.access_mode ?? "coins_or_vip"])}
                  </span>
                ),
              },
              { key: "views", header: "Views", render: (d) => formatCompact(d.views) },
              {
                key: "actions",
                header: "",
                className: "text-right",
                render: (d) => (
                  <div className="flex justify-end gap-1">
                    {canPublish && d.review_status === "approved" && (
                      <Button size="sm" variant={d.status === "published" ? "ghost" : "primary"} onClick={() => openPublish(d)}>
                        {d.status === "published" ? t("Rules") : t("Publish")}
                      </Button>
                    )}
                    {canPublish && d.status === "published" && (
                      <Button size="sm" variant="ghost" onClick={() => setUnpublishing(d)}>
                        {t("Unpublish")}
                      </Button>
                    )}
                    {hasPerm(user, "review") && ["submitted", "in_review"].includes(d.review_status ?? "") && (
                      <Button size="sm" variant="secondary" href={`/admin/reviews/${d.id}`}>
                        {t("Review")}
                      </Button>
                    )}
                    <Button size="sm" variant="ghost" href={`/admin/dramas/${d.id}/episodes`}>
                      {t("Episodes")}
                    </Button>
                    {canContent && (
                      <>
                        <Button size="sm" variant="ghost" onClick={() => openEdit(d)}>
                          {t("Edit")}
                        </Button>
                        <button
                          onClick={() => setDeleting(d)}
                          className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                          aria-label={t("Delete {name}", { name: d.title })}
                        >
                          <Icon name="trash" size={16} />
                        </button>
                      </>
                    )}
                  </div>
                ),
              },
            ]}
          />
          <Pagination meta={meta} onPage={setPage} />
        </>
      )}

      <Modal open={!!publishing && !!pform} onClose={() => setPublishing(null)} title={t("Publish {name}", { name: publishing?.title ?? "" })} size="lg">
        {pform && publishing && (
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="grid grid-cols-2 gap-1 rounded-xl bg-surface-2 p-1 text-sm font-semibold sm:col-span-2">
              {(
                [
                  ["now", "Publish now"],
                  ["schedule", "Schedule"],
                ] as const
              ).map(([k, label]) => (
                <button
                  key={k}
                  type="button"
                  onClick={() => setP("when", k)}
                  className={cn("rounded-lg py-2 transition", pform.when === k ? "bg-surface text-text shadow" : "text-text-dim hover:text-text")}
                >
                  {t(label)}
                </button>
              ))}
            </div>
            {pform.when === "schedule" && (
              <Field label="Publishing date and time" className="sm:col-span-2">
                <Input type="datetime-local" value={pform.publish_at} onChange={(e) => setP("publish_at", e.target.value)} />
              </Field>
            )}
            <Field label="Free episodes" hint="Episodes 1…N are a free preview (default 8)">
              <Input type="number" min={0} value={pform.free_episodes} onChange={(e) => setP("free_episodes", e.target.value)} />
            </Field>
            <Field label="Coins per episode" hint="Price to unlock one locked episode">
              <Input type="number" min={0} value={pform.coins_per_episode} onChange={(e) => setP("coins_per_episode", e.target.value)} />
            </Field>
            <Field label="Access to locked episodes" className="sm:col-span-2">
              <Select value={pform.access_mode} onChange={(e) => setP("access_mode", e.target.value as AccessMode)}>
                {(Object.keys(ACCESS_MODE_LABEL) as AccessMode[]).map((m) => (
                  <option key={m} value={m}>
                    {t(ACCESS_MODE_LABEL[m])}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Badge">
              <Select value={pform.badge} onChange={(e) => setP("badge", e.target.value)}>
                <option value="">{t("None")}</option>
                <option value="hot">{t("Hot")}</option>
                <option value="new">{t("New")}</option>
                <option value="vip">VIP</option>
              </Select>
            </Field>
            <label className="flex items-center justify-between gap-3 rounded-xl border border-border px-4 py-3 text-sm">
              <span className="font-semibold">{t("Featured on home")}</span>
              <Toggle checked={pform.is_featured} onChange={(v) => setP("is_featured", v)} label="Featured on home" />
            </label>
            <Notice tone="info" className="sm:col-span-2">
              {t("Only approved episodes are shown to viewers. Changes are recorded in the audit log.")}
            </Notice>
            <div className="flex justify-end gap-2 sm:col-span-2">
              <Button variant="ghost" onClick={() => setPublishing(null)}>
                {t("Cancel")}
              </Button>
              <Button loading={busy} onClick={publish}>
                {pform.when === "schedule" ? t("Schedule") : t("Publish now")}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      <Modal
        open={!!editing && !!form}
        onClose={() => setEditing(null)}
        title={editing === "new" ? t("Add series") : t("Edit {name}", { name: typeof editing === "object" && editing ? editing.title : "" })}
        size="lg"
      >
        {form && (
          <form onSubmit={save} className="grid gap-4 sm:grid-cols-2">
            {editing === "new" && (
              <Field label="Creator" className="sm:col-span-2">
                <Select required value={form.company_id} onChange={set("company_id")}>
                  <option value="">{t("Choose a creator")}</option>
                  {companyList.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </Select>
              </Field>
            )}
            <Field label="Title" className="sm:col-span-2">
              <Input required value={form.title} onChange={set("title")} />
            </Field>
            <Field label="Synopsis" className="sm:col-span-2">
              <Textarea value={form.synopsis} onChange={set("synopsis")} rows={4} />
            </Field>
            <Field label="Cover URL (3:4)">
              <Input type="url" value={form.poster_url} onChange={set("poster_url")} />
            </Field>
            <Field label="Backdrop URL (16:9)">
              <Input type="url" value={form.backdrop_url} onChange={set("backdrop_url")} />
            </Field>
            <Field label="Trailer URL" hint="Leave empty to keep the uploaded trailer">
              <Input type="url" value={form.trailer_url} onChange={set("trailer_url")} />
            </Field>
            <Field label="Age rating">
              <Select value={form.age_rating} onChange={set("age_rating")}>
                <option value="">{t("Not set")}</option>
                {AGE_RATINGS.map((r) => (
                  <option key={r} value={r}>
                    {t(AGE_RATING_LABEL[r])}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Genre" className="sm:col-span-2">
              <div className="flex flex-wrap gap-2">
                {categoryList.map((c) => {
                  const on = form.category_ids.includes(c.id);
                  return (
                    <button
                      type="button"
                      key={c.id}
                      onClick={() =>
                        setForm((f) => (f ? { ...f, category_ids: on ? f.category_ids.filter((x) => x !== c.id) : [...f.category_ids, c.id] } : f))
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
              </div>
            </Field>
            <p className="text-xs text-text-dim sm:col-span-2">{t("Publishing rules (date, price, free episodes, VIP) are set with Publish.")}</p>
            <div className="flex justify-end gap-2 sm:col-span-2">
              <Button type="button" variant="ghost" onClick={() => setEditing(null)}>
                {t("Cancel")}
              </Button>
              <Button type="submit" loading={saving}>
                {editing === "new" ? t("Create series") : t("Save changes")}
              </Button>
            </div>
          </form>
        )}
      </Modal>

      <ConfirmModal
        open={!!unpublishing}
        onClose={() => setUnpublishing(null)}
        onConfirm={unpublish}
        loading={busy}
        title="Unpublish series?"
        message="Viewers will no longer see it. You can publish it again later."
        confirmLabel="Unpublish"
      />
      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={remove}
        loading={busy}
        danger
        title="Delete series?"
        message={
          <>
            <b className="text-text">{deleting?.title}</b> {t("and all of its episodes will be removed permanently.")}
          </>
        }
        confirmLabel="Delete"
      />
    </>
  );
}
