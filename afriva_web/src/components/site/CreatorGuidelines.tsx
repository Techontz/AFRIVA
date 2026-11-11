"use client";

import { useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { pct, useRevenueSplit } from "@/lib/creator";
import { Button } from "../ui/Button";
import { Modal } from "../ui/Modal";

/** The Afriva creator guidelines; the revenue split comes from the admin setting via the API. */
export function CreatorGuidelinesModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useT().creator.guidelines;
  const split = useRevenueSplit(open);

  return (
    <Modal open={open} onClose={onClose} title={t.title} size="lg">
      <div className="space-y-4 text-sm text-text-muted">
        <p>{t.intro}</p>
        {split ? (
          <ol className="list-decimal space-y-2 pl-5">
            {t.points.map((p, i) => (
              <li key={i}>{fmt(p, { creator: pct(split.creator_percent), platform: pct(split.platform_percent) })}</li>
            ))}
          </ol>
        ) : (
          <p>{t.loading}</p>
        )}
        <div className="flex justify-end">
          <Button type="button" onClick={onClose}>
            {t.close}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
