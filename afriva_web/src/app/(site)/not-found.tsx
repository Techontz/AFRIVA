import { NotFoundContent } from "@/components/site/NotFoundContent";

/** notFound() inside the site (e.g. an unknown series): the (site) layout already renders the header and footer. */
export default function SiteNotFound() {
  return <NotFoundContent />;
}
