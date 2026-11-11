import Image from "next/image";
import { cn } from "@/lib/format";

// Brand artwork lives in public/brand: the red AFRIVA wordmark (1388:482) and a square icon.
const LOGO_RATIO = 1388 / 482;
const ASSETS = (process.env.NEXT_PUBLIC_ASSET_PREFIX ?? "").replace(/\/+$/, "");

/** Afriva logo: the red AFRIVA wordmark block. `size` sets the visual weight like a font size. */
export function Logo({ className, size = 26 }: { className?: string; size?: number }) {
  const height = Math.round(size * 1.25);
  const width = Math.round(height * LOGO_RATIO);
  return (
    <Image
      src={`${ASSETS}${height > 48 ? "/brand/logo.webp" : "/brand/logo-480.webp"}`}
      alt="Afriva"
      width={width}
      height={height}
      priority
      className={cn("inline-block select-none rounded-[3px]", className)}
      style={{ width, height }}
    />
  );
}

/** Square app icon: the wordmark centered on a red rounded square. */
export function LogoMark({ size = 26 }: { size?: number }) {
  return (
    <Image
      src={`${ASSETS}${size > 96 ? "/brand/icon-512.webp" : "/brand/icon-192.webp"}`}
      alt=""
      aria-hidden="true"
      width={size}
      height={size}
      className="select-none"
      style={{ width: size, height: size, borderRadius: size * 0.22 }}
    />
  );
}
