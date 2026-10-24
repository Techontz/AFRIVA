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
import type { Category, Drama } from "@/lib/types";

export function TagInput({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  const [text, setText] = useState("");
  const commit = (raw: string) => {
    const parts = raw
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);
    if (!parts.length) return;
    const next = [...value];
    for (const p of parts) if (!next.some((t) => t.toLowerCase() === p.toLowerCase())) next.push(p);
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
      {value.map((t) => (
        <span key={t} className="inline-flex items-center gap-1 rounded-full bg-surface-2 py-0.5 pl-2.5 pr-1 text-xs font-semibold">
          {t}
          <button
            type="button"
            onClick={() => onChange(value.filter((x) => x !== t))}
            className="grid h-4 w-4 place-items-center rounded-full text-text-dim hover:bg-border hover:text-text"
            aria-label={`Remove tag ${t}`}
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
        placeholder={value.length ? "" : "Billionaire, Secret Identity…"}
        className="min-w-[120px] flex-1 bg-transparent px-1 text-sm placeholder:text-text-dim focus:outline-none"
        aria-label="Add tag"
      />
    </div>
  );
}

interface FormState {
  title: string;
  synopsis: string;
  poster: MediaValue;
  backdrop: MediaValue;
  category_ids: number[];
  tags: string[];
  language: string;
  release_date: string;
  badge: string;
  free_episodes: string;
  coins_per_episode: string;
  status: "draft" | "published";
}

function initial(d?: Drama): FormState {
  return {
    title: d?.title ?? "",
    synopsis: d?.synopsis ?? "",
    poster: { url: d?.poster_url ?? "", file: null },
    backdrop: { url: d?.backdrop_url ?? "", file: null },
    category_ids: d?.categories?.map((c) => c.id) ?? [],
    tags: d?.tags ?? [],
    language: d?.language ?? "Swahili",
    release_date: d?.release_date ? d.release_date.slice(0, 10) : "",
    badge: d?.badge ?? "",
    free_episodes: String(d?.free_episodes ?? 5),
    coins_per_episode: String(d?.coins_per_episode ?? 30),
    status: d?.status ?? "draft",
  };
}

export function DramaForm({ drama }: { drama?: Drama }) {
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
    if (!f.title.trim()) {
      setErrors({ title: ["Title is required"] });
      return;
    }
    setSaving(true);
    setErrors({});
    const scalar = {
      title: f.title.trim(),
      synopsis: f.synopsis,
      language: f.language || null,
      release_date: f.release_date || null,
      badge: f.badge || null,
      free_episodes: Number(f.free_episodes) || 0,
      coins_per_episode: Number(f.coins_per_episode) || 0,
      status: f.status,
    };
    let body: FormData | Record<string, unknown>;
    if (f.poster.file || f.backdrop.file) {
      const fd = new FormData();
      for (const [k, v] of Object.entries(scalar)) if (v !== null) fd.append(k, String(v));
      appendMedia(fd, "poster", f.poster);
      appendMedia(fd, "backdrop", f.backdrop);
      f.category_ids.forEach((id) => fd.append("category_ids[]", String(id)));
      f.tags.forEach((t) => fd.append("tags[]", t));
      body = fd;
    } else {
      body = {
        ...scalar,
        poster_url: f.poster.url || null,
        backdrop_url: f.backdrop.url || null,
        category_ids: f.category_ids,
        tags: f.tags,
      };
    }
    try {
      if (drama) {
        await api.put<Drama>(`/studio/dramas/${drama.id}`, body);
        toast.success("Drama saved");
        router.refresh();
      } else {
        const created = await api.post<Drama>("/studio/dramas", body);
        toast.success("Drama created — now add episodes");
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
      <div className="space-y-4">
        <Card title="Details">
          <div className="grid gap-4">
            <Field label="Title" htmlFor="title" error={err("title")}>
              <Input id="title" value={f.title} onChange={(e) => set("title", e.target.value)} placeholder="Bride of Kilimanjaro" />
            </Field>
            <Field label="Synopsis" htmlFor="synopsis" error={err("synopsis")}>
              <Textarea
                id="synopsis"
                rows={5}
                value={f.synopsis}
                onChange={(e) => set("synopsis", e.target.value)}
                placeholder="A hook that makes viewers press play…"
              />
            </Field>
            <Field label="Categories" error={err("category_ids")}>
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
                <p className="text-xs text-text-dim">Categories couldn&apos;t be loaded.</p>
              )}
            </Field>
            <Field label="Tags" hint="Press Enter or comma to add" error={err("tags")}>
              <TagInput value={f.tags} onChange={(v) => set("tags", v)} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-3">
              <Field label="Language" htmlFor="language">
                <Select id="language" value={f.language} onChange={(e) => set("language", e.target.value)}>
                  {["Swahili", "English", "Yoruba", "Hausa", "Igbo", "Amharic", "French", "Zulu"].map((l) => (
                    <option key={l}>{l}</option>
                  ))}
                </Select>
              </Field>
              <Field label="Release date" htmlFor="release_date" error={err("release_date")}>
                <Input id="release_date" type="date" value={f.release_date} onChange={(e) => set("release_date", e.target.value)} />
              </Field>
              <Field label="Badge" htmlFor="badge">
                <Select id="badge" value={f.badge} onChange={(e) => set("badge", e.target.value)}>
                  <option value="">None</option>
                  <option value="hot">Hot</option>
                  <option value="new">New</option>
                  <option value="vip">VIP</option>
                </Select>
              </Field>
            </div>
          </div>
        </Card>

        <Card title="Monetisation">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Free episodes" htmlFor="free" hint="Episodes 1…N are free for everyone" error={err("free_episodes")}>
              <Input id="free" type="number" min={0} value={f.free_episodes} onChange={(e) => set("free_episodes", e.target.value)} />
            </Field>
            <Field label="Coins per episode" htmlFor="coins" hint="Price to unlock one locked episode" error={err("coins_per_episode")}>
              <Input id="coins" type="number" min={0} value={f.coins_per_episode} onChange={(e) => set("coins_per_episode", e.target.value)} />
            </Field>
          </div>
        </Card>
      </div>

      <div className="space-y-4">
        <Card title="Artwork">
          <div className="space-y-5">
            <MediaInput label="Poster (3:4)" value={f.poster} onChange={(v) => set("poster", v)} />
            <MediaInput label="Backdrop (16:9)" value={f.backdrop} onChange={(v) => set("backdrop", v)} aspect="aspect-video w-48!" />
            {(err("poster") || err("poster_url") || err("backdrop")) && (
              <p className="text-xs text-danger">{err("poster") || err("poster_url") || err("backdrop")}</p>
            )}
          </div>
        </Card>
        <Card title="Visibility">
          <div className="grid grid-cols-2 gap-2 rounded-xl bg-surface-2 p-1">
            {(["draft", "published"] as const).map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => set("status", s)}
                aria-pressed={f.status === s}
                className={cn(
                  "rounded-lg py-2 text-sm font-semibold capitalize transition",
                  f.status === s ? (s === "published" ? "bg-success/20 text-success" : "bg-surface text-text") : "text-text-dim hover:text-text",
                )}
              >
                {s}
              </button>
            ))}
          </div>
          <p className="mt-2 text-xs text-text-dim">
            {f.status === "published" ? "Visible to viewers on Afriva." : "Only you can see drafts."}
          </p>
        </Card>
        <div className="flex gap-2 lg:sticky lg:top-6">
          <Button type="button" variant="secondary" className="flex-1" onClick={() => router.push("/studio/dramas")}>
            Cancel
          </Button>
          <Button type="submit" loading={saving} className="flex-1">
            {drama ? "Save changes" : "Create drama"}
          </Button>
        </div>
      </div>
    </form>
  );
}
