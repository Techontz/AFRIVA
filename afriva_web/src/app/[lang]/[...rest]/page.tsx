import { notFound } from "next/navigation";
import { Suspense } from "react";

async function Missing({ params }: { params: Promise<unknown> }): Promise<null> {
  await params;
  notFound();
  return null;
}

/** Unmatched URLs land here after the proxy rewrite, so the 404 renders inside the localized root layout. */
export default function CatchAll({ params }: PageProps<"/[lang]/[...rest]">) {
  return (
    <Suspense>
      <Missing params={params} />
    </Suspense>
  );
}
