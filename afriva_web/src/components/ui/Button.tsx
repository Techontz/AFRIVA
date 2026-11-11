import Link from "next/link";
import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/format";
import { Spinner } from "./Feedback";

type Variant = "primary" | "secondary" | "ghost" | "outline" | "danger" | "gold";
type Size = "sm" | "md" | "lg" | "icon";

const variants: Record<Variant, string> = {
  primary:
    "bg-primary text-white hover:bg-primary-hover active:bg-primary-hover",
  secondary: "bg-surface-2 text-text hover:bg-surface-3 border border-transparent",
  ghost: "bg-transparent text-text-muted hover:text-text hover:bg-surface-2",
  outline: "border border-border text-text hover:border-text-dim hover:bg-surface-2",
  danger: "bg-danger/15 text-danger hover:bg-danger/25 border border-danger/30",
  gold: "bg-text text-bg hover:opacity-90",
};

const sizes: Record<Size, string> = {
  sm: "h-8 px-3.5 text-[13px] gap-1.5",
  md: "h-10 px-5 text-sm gap-2",
  lg: "h-12 px-7 text-[15px] gap-2.5",
  icon: "h-10 w-10 justify-center",
};

export function buttonClass(variant: Variant = "primary", size: Size = "md", className?: string) {
  return cn(
    "inline-flex items-center justify-center rounded-full font-semibold whitespace-nowrap select-none",
    "transition-all duration-200 ease-out disabled:opacity-50 disabled:pointer-events-none",
    variants[variant],
    sizes[size],
    className,
  );
}

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  href?: string;
  children?: ReactNode;
}

export function Button({ variant = "primary", size = "md", loading, href, className, children, disabled, ...rest }: Props) {
  const cls = buttonClass(variant, size, className);
  if (href) {
    return (
      <Link href={href} className={cls}>
        {children}
      </Link>
    );
  }
  return (
    <button className={cls} disabled={disabled || loading} {...rest}>
      {loading && <Spinner size={16} />}
      {children}
    </button>
  );
}
