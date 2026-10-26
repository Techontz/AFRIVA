"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent, type KeyboardEvent } from "react";
import { toast } from "sonner";
import { Card } from "@/components/portal/Kit";
import { appendMedia, MediaInput, type MediaValue } from "@/components/portal/MediaInput";
import { Button } from "@/components/ui/Button";
import { Skeleton } from "@/components/ui/Feedback";
import { Field, Input, Select, Textarea } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { api, ApiError, asArray, errorMessage } from "@/lib/api";
import { cn } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import { ACCESS_MODE_LABEL, AGE_RATING_LABEL, AGE_RATINGS } from "@/lib/portal";
import type { AgeRating, Category, Drama } from "@/lib/types";
import { Notice } from "@/components/portal/ScopeKit";

export function TagInput({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  const t = useT();
  const [text, setText] = useState("");
  const commit = (raw: string) => {
    const parts = raw
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    if (!parts.length) return;
    const next = [...value];
    for (const p of parts) if (!next.some((x) => x.toLowerCase() === p.toLowerCase())) next.push(p);
    onChange(next);
    setText("");
  };
  const onKey = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter" || e.key === ",") {
      e.preventDefault();
      commit(text);
    } else if (e.key === "Backspace" && !text && value.length) {
      onChange(value.slice(0, -1));
    }
  };
  return (
    <div className="flex min-h-[44px] flex-wrap items-center gap-1.5 rounded-xl border border-border bg-surface px-2.5 py-2 focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/25">
      {value.map((tag) => (
        <span key={tag} className="inline-flex items-center gap-1 rounded-full bg-surface-2 py-0.5 pl-2.5 pr-1 text-xs font-semibold">
          {tag}
          <button
            type="button"
            onClick={() => onChange(value.filter((x) => x !== tag))}
            className="grid h-4 w-4 place-items-center rounded-full text-text-dim hover:bg-border hover:text-text"
            aria-label={t("Remove tag {tag}", { tag })}
          >
            <Icon name="x" size={11} strokeWidth={2.5} />
          </button>
        </span>
      ))}
      <input
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={onKey}
        onBlur={() => commit(text)}
        placeholder={value.length ? "" : t("Billionaire, Secret Identity…")}
        className="min-w-[120px] flex-1 bg-transparent px-1 text-sm placeholder:text-text-dim focus:outline-none"
        aria-label={t("Add tag")}
      />
    </div>
  );
}

interface FormState {
  title: string;
  synopsis: string;
  poster: MediaValue;
  backdrop: MediaValue;
  trailer: MediaValue;
  category_ids: number[];
  tags: string[];
  language: string;
  age_rating: AgeRating | "";
}

function initial(d?: Drama): FormState {
  return {
    title: d?.title ?? "",
    synopsis: d?.synopsis ?? "",
    poster: { url: d?.poster_url ?? "", file: null },
    backdrop: { url: d?.backdrop_url && d.backdrop_url !== d.poster_url ? d.backdrop_url : "", file: null },
    trailer: { url: d?.trailer_url ?? "", file: null },
    category_ids: d?.categories?.map((c) => c.id) ?? [],
    tags: d?.tags ?? [],
    language: d?.language ?? "sw",
    age_rating: d?.age_rating ?? "",
  };
}

const LANGUAGES: [string, string][] = [
  ["sw", "Swahili"],
  ["en", "English"],
  ["yo", "Yoruba"],
  ["ha", "Hausa"],
  ["ig", "Igbo"],
  ["am", "Amharic"],
  ["fr", "French"],
  ["zu", "Zulu"],
];

/**
 * Creator series form (scope §04 "Tuma kazi"): details, genre, cover, trailer.
 * Publishing rules (date, price, free episodes, VIP) are set by AFRIVA staff, not here.
 */
export function DramaForm({ drama, readOnly, onSaved }: { drama?: Drama; readOnly?: boolean; onSaved?: (d: Drama) => void }) {
  const t = useT();
  const router = useRouter();
  const [f, setF] = useState<FormState>(() => initial(drama));
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  const cats = useApi<Category[]>("/categories");
  const categories = asArray<Category>(cats.data);

  const set = <K extends keyof FormState>(k: K, v: FormState[K]) => setF((s) => ({ ...s, [k]: v }));
  const err = (k: string) => errors[k]?.[0] ?? null;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (readOnly) return;
    if (!f.title.trim()) {
      setErrors({ title: [t("Title is required")] });
      return;
    }
    setSaving(true);
    setErrors({});
    const scalar = {
      title: f.title.trim(),
      synopsis: f.synopsis,
      language: f.language || null,
      age_rating: f.age_rating || null,
    };
    let body: FormData | Record<string, unknown>;
    if (f.poster.file || f.backdrop.file || f.trailer.file) {
      const fd = new FormData();
      for (const [k, v] of Object.entries(scalar)) if (v !== null) fd.append(k, String(v));
      appendMedia(fd, "poster", f.poster);
      appendMedia(fd, "backdrop", f.backdrop);
      appendMedia(fd, "trailer", f.trailer);
      f.category_ids.forEach((id) => fd.append("category_ids[]", String(id)));
      f.tags.forEach((tag) => fd.append("tags[]", tag));
      body = fd;
    } else {
      body = {
        ...scalar,
        poster_url: f.poster.url || null,
        backdrop_url: f.backdrop.url || null,
        trailer_url: f.trailer.url || null,
        category_ids: f.category_ids,
        tags: f.tags,
      };
    }
    try {
      if (drama) {
        const saved = await api.put<Drama>(`/studio/dramas/${drama.id}`, body);
        toast.success(t("Series saved"));
        if (saved) onSaved?.(saved);
      } else {
        const created = await api.post<Drama>("/studio/dramas", body);
        toast.success(t("Series created. Now add episodes"));
        router.push(created?.id ? `/studio/dramas/${created.id}/episodes` : "/studio/dramas");
      }
    } catch (e) {
      if (e instanceof ApiError && e.errors) setErrors(e.errors);
      toast.error(errorMessage(e));
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={submit} className="grid gap-4 lg:grid-cols-[1fr_320px]">
      <fieldset disabled={readOnly} className="min-w-0 space-y-4 disabled:opacity-80">
        <Card title={t("Details")}>
          <div className="grid gap-4">
            <Field label={t("Title")} htmlFor="title" error={err("title")}>
              <Input id="title" value={f.title} onChange={(e) => set("title", e.target.value)} placeholder="Siri ya Usiku" />
            </Field>
            <Field label={t("Synopsis")} htmlFor="synopsis" error={err("synopsis")}>
              <Textarea
                id="synopsis"
                rows={5}
                value={f.synopsis}
                onChange={(e) => set("synopsis", e.target.value)}
                placeholder={t("A hook that makes viewers press play…")}
              />
            </Field>
            <Field label={t("Genre")} error={err("category_ids")}>
              {cats.loading ? (
                <div className="flex gap-2">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Skeleton key={i} className="h-8 w-20 rounded-full" />
                  ))}
                </div>
              ) : categories.length ? (
                <div className="flex flex-wrap gap-2">
                  {categories.map((c) => {
                    const on = f.category_ids.includes(c.id);
                    return (
                      <button
                        type="button"
                        key={c.id}
                        aria-pressed={on}
                        onClick={() =>
                          set("category_ids", on ? f.category_ids.filter((x) => x !== c.id) : [...f.category_ids, c.id])
                        }
                        className={cn(
                          "inline-flex items-center gap-1 rounded-full border px-3 py-1.5 text-xs font-semibold transition",
                          on ? "border-transparent bg-primary text-white" : "border-border text-text-muted hover:border-text-dim hover:text-text",
                        )}
                      >
                        {on && <Icon name="check" size={13} strokeWidth={2.5} />}
                        {c.name}
                      </button>
                    );
                  })}
                </div>
              ) : (
                <p className="text-xs text-text-dim">{t("Categories couldn't be loaded.")}</p>
              )}
            </Field>
            <Field label={t("Tags")} hint={t("Press Enter or comma to add")} error={err("tags")}>
              <TagInput value={f.tags} onChange={(v) => set("tags", v)} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label={t("Language")} htmlFor="language">
                <Select id="language" value={f.language} onChange={(e) => set("language", e.target.value)}>
                  {LANGUAGES.map(([code, label]) => (
                    <option key={code} value={code}>
                      {t(label)}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label={t("Age rating")} htmlFor="age_rating" error={err("age_rating")}>
                <Select id="age_rating" value={f.age_rating} onChange={(e) => set("age_rating", e.target.value as AgeRating | "")}>
                  <option value="">{t("Not set")}</option>
                  {AGE_RATINGS.map((r) => (
                    <option key={r} value={r}>
                      {t(AGE_RATING_LABEL[r])}
                    </option>
                  ))}
                </Select>
              </Field>
            </div>
          </div>
        </Card>

        <Card title={t("Trailer")}>
          <MediaInput label={t("Trailer video (optional)")} kind="video" accept="video/*" value={f.trailer} onChange={(v) => set("trailer", v)} />
          {(err("trailer") || err("trailer_url")) && <p className="mt-2 text-xs text-danger">{err("trailer") || err("trailer_url")}</p>}
        </Card>
      </fieldset>

      <div className="space-y-4">
        <fieldset disabled={readOnly} className="disabled:opacity-80">
          <Card title={t("Cover and artwork")}>
            <div className="space-y-5">
              <MediaInput label={t("Cover (3:4)")} value={f.poster} onChange={(v) => set("poster", v)} />
              <MediaInput label={t("Backdrop (16:9, optional)")} value={f.backdrop} onChange={(v) => set("backdrop", v)} aspect="aspect-video w-48!" />
              {(err("poster") || err("poster_url") || err("backdrop")) && (
                <p className="text-xs text-danger">{err("poster") || err("poster_url") || err("backdrop")}</p>
              )}
            </div>
          </Card>
        </fieldset>
        <Card title={t("Publishing rules")}>
          <p className="text-xs text-text-muted">
            {t("AFRIVA sets the publishing date, coin price, free episodes and VIP access after approving your series.")}
          </p>
          {drama && (
            <dl className="mt-3 grid grid-cols-2 gap-2 text-xs">
              <dt className="text-text-dim">{t("Free episodes")}</dt>
              <dd className="text-right font-semibold">{t("1–{n}", { n: drama.free_episodes })}</dd>
              <dt className="text-text-dim">{t("Coins per episode")}</dt>
              <dd className="text-right font-semibold">{drama.coins_per_episode}</dd>
              <dt className="text-text-dim">{t("Access")}</dt>
              <dd className="text-right font-semibold">{t(ACCESS_MODE_LABEL[drama.access_mode ?? "coins_or_vip"])}</dd>
            </dl>
          )}
        </Card>
        {readOnly ? (
          <Notice tone="info" icon="lock">
            {t("This series is under review or approved, so it can't be changed now.")}
          </Notice>
        ) : (
          <div className="flex gap-2 lg:sticky lg:top-6">
            <Button type="button" variant="secondary" className="flex-1" onClick={() => router.push("/studio/dramas")}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={saving} className="flex-1">
              {drama ? t("Save changes") : t("Create series")}
            </Button>
          </div>
        )}
      </div>
    </form>
  );
}
