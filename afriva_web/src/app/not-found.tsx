import { Footer } from "@/components/site/Footer";
import { Header } from "@/components/site/Header";
import { NotFoundContent } from "@/components/site/NotFoundContent";

/** Unmatched URLs: rendered only inside the root layout, so it brings its own header and footer. */
export default function NotFound() {
  return (
    <>
      <Header />
      <NotFoundContent />
      <Footer />
    </>
  );
}
