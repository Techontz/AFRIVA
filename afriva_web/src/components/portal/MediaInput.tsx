"use client";

import { useEffect, useId, useMemo, useState } from "react";
import { cn } from "@/lib/format";
import { useT } from "@/lib/i18n";
import { Icon } from "../ui/Icon";
import { inputClass } from "../ui/Form";

export interface MediaValue {
  url: string;
  file: File | null;
}

/**
 * URL-or-upload input used for posters, backdrops and episode videos.
 * The parent decides how to send it (JSON `*_url` vs multipart file field).
 */
export function MediaInput({
  label,
  value,
  onChange,
  accept = "image/*",
  kind = "image",
  aspect = "aspect-[3/4]",
}: {
  label: string;
  value: MediaValue;
  onChange: (v: MediaValue) => void;
  accept?: string;
  kind?: "image" | "video";
  aspect?: string;
}) {
  const id = useId();
  const t = useT();
  const [mode, setMode] = useState<"url" | "file">(value.file ? "file" : "url");
  const preview = useMemo(() => (value.file ? URL.createObjectURL(value.file) : null), [value.file]);
  useEffect(() => {
    if (!preview) return;
    return () => URL.revokeObjectURL(preview);
  }, [preview]);

  const shown = preview ?? (value.url || null);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="text-[13px] font-semibold text-text-muted">{t(label)}</span>
        <div className="flex rounded-full bg-surface-2 p-0.5 text-[11px] font-semibold">
          {(["url", "file"] as const).map((m) => (
            <button
              key={m}
              type="button"
              onClick={() => setMode(m)}
              className={cn(
                "rounded-full px-2.5 py-1 transition",
                mode === m ? "bg-surface text-text shadow" : "text-text-dim hover:text-text",
              )}
            >
              {m === "url" ? "URL" : t("Upload")}
            </button>
          ))}
        </div>
      </div>
      {mode === "url" ? (
        <input
          type="url"
          placeholder={kind === "video" ? "https://…/episode.mp4" : "https://…/poster.jpg"}
          className={inputClass}
          value={value.url}
          onChange={(e) => onChange({ url: e.target.value, file: null })}
        />
      ) : (
        <label
          htmlFor={id}
          className="flex cursor-pointer items-center gap-3 rounded-xl border border-dashed border-border bg-surface px-3.5 py-3 text-sm text-text-muted transition hover:border-primary hover:text-text"
        >
          <Icon name="upload" size={18} />
          <span className="truncate">{value.file ? value.file.name : t(kind === "video" ? "Choose video file…" : "Choose image file…")}</span>
          <input
            id={id}
            type="file"
            accept={accept}
            className="sr-only"
            onChange={(e) => {
              const f = e.target.files?.[0] ?? null;
              onChange({ url: value.url, file: f });
            }}
          />
        </label>
      )}
      {kind === "image" && shown && (
        <div className={cn("w-28 overflow-hidden rounded-lg border border-border bg-surface-2", aspect)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={shown} alt="" className="h-full w-full object-cover" />
        </div>
      )}
      {kind === "video" && shown && (
        <video src={shown} className="h-32 w-auto max-w-full rounded-lg border border-border bg-black" controls muted preload="metadata" />
      )}
    </div>
  );
}

/** Adds a MediaValue to FormData as either `<field>` (file) or `<field>_url`. */
export function appendMedia(fd: FormData, field: string, v: MediaValue) {
  if (v.file) fd.append(field, v.file);
  else if (v.url) fd.append(`${field}_url`, v.url);
}
