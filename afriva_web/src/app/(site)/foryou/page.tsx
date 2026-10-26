import type { Metadata } from "next";
import { ForYouFeed } from "@/components/site/ForYouFeed";

export const metadata: Metadata = {
  title: "Kwa Ajili Yako",
  description: "Pitia episode za kwanza za series za AFRIVA na upate hadithi yako ijayo.",
};

export default function ForYouPage() {
  return <ForYouFeed />;
}
