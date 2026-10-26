import { cn } from "@/lib/format";

const LOGO_SRC = "/afriva-logo.png";
const LOGO_RATIO = 900 / 293;

/** Afriva logo: white "AFRIVA" wordmark on a red block. `size` matches the old text size. */
export function Logo({ className, size = 26 }: { className?: string; size?: number }) {
  return <LogoImage height={size * 1.25} className={className} />;
}

/** Compact logo for standalone spots (auth card, loading screens). */
export function LogoMark({ size = 26 }: { size?: number }) {
  return <LogoImage height={size * 0.75} />;
}

function LogoImage({ height, className }: { height: number; className?: string }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={LOGO_SRC}
      alt="Afriva"
      width={Math.round(height * LOGO_RATIO)}
      height={Math.round(height)}
      className={cn("inline-block shrink-0 select-none", className)}
      draggable={false}
    />
  );
}
