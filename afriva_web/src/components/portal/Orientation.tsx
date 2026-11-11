"use client";

import { useT } from "@/i18n/client";
import { cn } from "@/lib/format";
import type { EpisodeOrientation } from "@/lib/types";

/** Small screen glyph: tall for portrait, wide for landscape. */
export function OrientationGlyph({ value, size = 16, className }: { value: EpisodeOrientation; size?: number; className?: string }) {
  const tall = value !== "landscape";
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth={1.8} aria-hidden="true" className={className}>
      {tall ? <rect x="7" y="2.5" width="10" height="19" rx="2" /> : <rect x="2.5" y="6" width="19" height="12" rx="2" />}
      <path d={tall ? "M10.5 18.5h3" : "M18.5 10.5v3"} strokeLinecap="round" />
    </svg>
  );
}

/** Orientation icon with an accessible label, for episode lists. */
export function OrientationBadge({ value }: { value: EpisodeOrientation | undefined }) {
  const t = useT().portal.orientation;
  const v = value ?? "portrait";
  const label = v === "landscape" ? t.landscape : t.portrait;
  return (
    <span className="inline-flex items-center gap-1 text-xs text-text-muted" title={label}>
      <OrientationGlyph value={v} size={15} />
      <span className="sr-only">{label}</span>
    </span>
  );
}

/** Vertical (9:16) / Horizontal (16:9) choice for the episode forms. */
export function OrientationPicker({
  value,
  onChange,
  disabled,
}: {
  value: EpisodeOrientation;
  onChange: (v: EpisodeOrientation) => void;
  disabled?: boolean;
}) {
  const t = useT().portal.orientation;
  const options: [EpisodeOrientation, string, string][] = [
    ["portrait", t.portrait, t.portraitHint],
    ["landscape", t.landscape, t.landscapeHint],
  ];
  return (
    <fieldset disabled={disabled}>
      <legend className="mb-1.5 text-sm font-semibold text-text">{t.label}</legend>
      <div className="grid grid-cols-2 gap-2" role="radiogroup">
        {options.map(([v, label, hint]) => (
          <button
            key={v}
            type="button"
            role="radio"
            aria-checked={value === v}
            onClick={() => onChange(v)}
            className={cn(
              "flex items-center gap-3 rounded-xl border px-3 py-2.5 text-left transition",
              value === v ? "border-primary bg-primary/10 text-text" : "border-border text-text-muted hover:border-text-dim/50 hover:text-text",
            )}
          >
            <OrientationGlyph value={v} size={22} className={value === v ? "text-primary" : undefined} />
            <span className="min-w-0">
              <span className="block text-sm font-semibold">{label}</span>
              <span className="block text-[11px] text-text-dim">{hint}</span>
            </span>
          </button>
        ))}
      </div>
    </fieldset>
  );
}
