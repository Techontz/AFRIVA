import { cn } from "@/lib/format";

/** Afriva logo: red rounded-square app icon with a white play mark + "Afriva" wordmark. */
export function Logo({ className, size = 26, mark = true }: { className?: string; size?: number; mark?: boolean }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5 select-none text-text", className)} aria-label="Afriva">
      {mark && <LogoMark size={size * 1.25} />}
      <span className="font-semibold leading-none tracking-[-0.02em]" style={{ fontSize: size * 0.94 }} aria-hidden="true">
        Afriva
      </span>
    </span>
  );
}

/** Red rounded-square app icon with a white play triangle. */
export function LogoMark({ size = 26 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      <rect width="32" height="32" rx="8" fill="#E1122B" />
      <path d="M12 9.4v13.2a1.4 1.4 0 0 0 2.12 1.2l10.6-6.6a1.4 1.4 0 0 0 0-2.4l-10.6-6.6A1.4 1.4 0 0 0 12 9.4Z" fill="#fff" />
    </svg>
  );
}
