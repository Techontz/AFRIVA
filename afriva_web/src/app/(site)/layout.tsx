import { Footer } from "@/components/site/Footer";
import { Header } from "@/components/site/Header";

export default function SiteLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="site-light flex min-h-full flex-1 flex-col">
      <Header />
      <main id="main" className="flex-1">
        {children}
      </main>
      <Footer />
    </div>
  );
}
