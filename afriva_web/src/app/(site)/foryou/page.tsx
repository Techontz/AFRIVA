import type { Metadata } from "next";
import { ForYouFeed } from "@/components/site/ForYouFeed";

export const metadata: Metadata = {
  title: "For You",
  description: "Swipe through the first episodes of Afriva's dramas and find your next binge.",
};

export default function ForYouPage() {
  return <ForYouFeed />;
}
