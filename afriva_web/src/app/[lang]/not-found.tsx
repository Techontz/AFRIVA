import Link from "next/link";
import { Footer } from "@/components/site/Footer";
import { Header } from "@/components/site/Header";
import { buttonClass } from "@/components/ui/Button";
import { getDict } from "@/i18n/server";

export default async function NotFound() {
  const t = (await getDict()).common.notFound;
  return (
    <>
      <Header />
      <main className="relative flex flex-1 items-center justify-center overflow-hidden px-4 py-24 text-center">
        <div className="pointer-events-none absolute left-1/2 top-1/2 h-[400px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary/10 blur-3xl" />
        <div className="relative">
          <p className="rank-outline-brand text-[120px] font-extrabold italic leading-none tracking-tighter sm:text-[160px]">404</p>
          <h1 className="mt-2 text-2xl font-extrabold">{t.title}</h1>
          <p className="mx-auto mt-2 max-w-md text-sm text-text-muted">{t.body}</p>
          <div className="mt-8 flex justify-center gap-3">
            <Link href="/" className={buttonClass("primary", "lg")}>
              {t.home}
            </Link>
            <Link href="/browse" className={buttonClass("secondary", "lg")}>
              {t.browse}
            </Link>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
