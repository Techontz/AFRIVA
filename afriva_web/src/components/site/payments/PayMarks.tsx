import { cn } from "@/lib/format";
import { NETWORKS, type NetworkCode, type SavedMethod } from "@/lib/payments";
import { Icon } from "../../ui/Icon";

/** Visa wordmark on a white card chip. */
export function VisaMark({ className }: { className?: string }) {
  return (
    <span
      className={cn("inline-grid h-6 w-9 shrink-0 place-items-center rounded-[5px] bg-white ring-1 ring-black/10", className)}
      aria-label="Visa"
      role="img"
    >
      <svg viewBox="0 0 48 16" className="h-[9px] w-auto" aria-hidden>
        <text
          x="24"
          y="14"
          textAnchor="middle"
          fontFamily="Arial, Helvetica, sans-serif"
          fontWeight="900"
          fontStyle="italic"
          fontSize="17"
          letterSpacing="-0.5"
          fill="#1a1f71"
        >
          VISA
        </text>
      </svg>
    </span>
  );
}

/** Mastercard interlocking circles on a white card chip. */
export function MastercardMark({ className }: { className?: string }) {
  return (
    <span
      className={cn("inline-grid h-6 w-9 shrink-0 place-items-center rounded-[5px] bg-white ring-1 ring-black/10", className)}
      aria-label="Mastercard"
      role="img"
    >
      <svg viewBox="0 0 32 20" className="h-3.5 w-auto" aria-hidden>
        <circle cx="12" cy="10" r="8" fill="#eb001b" />
        <circle cx="20" cy="10" r="8" fill="#f79e1b" />
        <path d="M16 3.07a8 8 0 0 1 0 13.86 8 8 0 0 1 0-13.86Z" fill="#ff5f00" />
      </svg>
    </span>
  );
}

export function CardBrandMark({ brand, className }: { brand: string | null | undefined; className?: string }) {
  if (brand === "visa") return <VisaMark className={className} />;
  if (brand === "mastercard") return <MastercardMark className={className} />;
  return (
    <span className={cn("inline-grid h-6 w-9 shrink-0 place-items-center rounded-[5px] bg-surface-3 text-text-dim", className)}>
      <Icon name="card" size={14} />
    </span>
  );
}

/** A small coloured monogram for a mobile money network. */
export function NetworkMark({ code, size = "md", className }: { code: string | null | undefined; size?: "sm" | "md" | "lg"; className?: string }) {
  const n = code && code in NETWORKS ? NETWORKS[code as NetworkCode] : null;
  const dims = { sm: "h-5 w-5 text-[10px] rounded-md", md: "h-9 w-9 text-sm rounded-xl", lg: "h-11 w-11 text-base rounded-2xl" }[size];
  return (
    <span
      className={cn("inline-grid shrink-0 place-items-center font-extrabold text-white", dims, !n && "bg-surface-3 text-text-dim", className)}
      style={n ? { background: `linear-gradient(145deg, ${n.color}, color-mix(in srgb, ${n.color} 70%, #000))` } : undefined}
      aria-hidden
    >
      {n ? n.short : <Icon name="phone" size={size === "sm" ? 11 : 16} />}
    </span>
  );
}

/** Icon tile for a saved method (network monogram or card brand chip). */
export function SavedMethodIcon({ method }: { method: SavedMethod }) {
  if (method.type === "card") {
    return (
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-surface-3">
        <CardBrandMark brand={method.card_brand ?? method.method_code} className="h-5 w-[30px]" />
      </span>
    );
  }
  return <NetworkMark code={method.method_code} />;
}
