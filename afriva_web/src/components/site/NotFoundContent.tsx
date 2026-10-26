import Link from "next/link";
import { buttonClass } from "@/components/ui/Button";
import { T } from "@/lib/i18n";

/** 404 body. The surrounding page supplies the header/footer (see app/not-found.tsx and app/(site)/not-found.tsx). */
export function NotFoundContent() {
  return (
    <main className="relative flex flex-1 items-center justify-center overflow-hidden px-4 py-24 text-center">
      <div className="pointer-events-none absolute left-1/2 top-1/2 h-[400px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary/10 blur-3xl" />
      <div className="relative">
        <p className="rank-outline-brand text-[120px] font-extrabold italic leading-none tracking-tighter sm:text-[160px]">404</p>
        <h1 className="mt-2 text-2xl font-extrabold"><T>{"Plot twist: this page doesn't exist"}</T></h1>
        <p className="mx-auto mt-2 max-w-md text-sm text-text-muted">
          <T>{"The episode you're looking for may have moved, or the link is wrong."}</T>
        </p>
        <div className="mt-8 flex justify-center gap-3">
          <Link href="/" className={buttonClass("primary", "lg")}>
            <T>Back to Home</T>
          </Link>
          <Link href="/browse" className={buttonClass("secondary", "lg")}>
            <T>Browse dramas</T>
          </Link>
        </div>
      </div>
    </main>
  );
}
