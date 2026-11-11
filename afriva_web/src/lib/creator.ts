"use client";

import { useEffect, useState } from "react";
import { api } from "./api";
import type { VideoUploadTicket } from "./types";

export type ReviewStatus = "pending" | "ready_for_review" | "approved" | "rejected";

export interface RevenueSplit {
  creator_percent: number;
  platform_percent: number;
}

export interface ApplicationSample {
  id: number;
  title: string | null;
  status: "uploading" | "processing" | "ready" | "failed";
  duration_seconds: number | null;
  length_check: "ok" | "too_short" | "too_long" | null;
  valid: boolean;
  playback_url?: string | null;
}

export interface SamplesSummary {
  required: number;
  uploaded: number;
  valid: number;
  min_seconds: number;
  max_seconds: number;
  max_bytes: number;
}

export interface CreatorApplication {
  id: number;
  status: "pending" | "approved" | "rejected";
  review_status: ReviewStatus;
  rejection_reason: string | null;
  company: { id: number; name: string; status: string } | null;
  samples: ApplicationSample[];
  samples_summary: SamplesSummary;
  revenue_split: RevenueSplit;
}

export interface PayoutAccount {
  method: "mobile_money" | "bank" | null;
  provider: string | null;
  bank_name: string | null;
  account_name: string | null;
  account_number: string | null;
}

export const PAYOUT_PROVIDERS = ["mpesa", "mixx", "airtel", "halopesa", "tpesa"] as const;

/** 60 -> "60", 62.5 -> "62.5" */
export const pct = (n: number | string | null | undefined) => {
  const v = Number(n ?? 0);
  return Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
};

export const mmss = (s: number | null | undefined) => {
  if (!s) return "";
  return `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, "0")}`;
};

/** The revenue split from the admin setting (never hard-coded). */
export function useRevenueSplit(enabled = true) {
  const [split, setSplit] = useState<RevenueSplit | null>(null);
  useEffect(() => {
    if (!enabled || split) return;
    let alive = true;
    api
      .get<RevenueSplit>("/creator-guidelines")
      .then((s) => alive && setSplit(s))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [enabled, split]);
  return split;
}

/**
 * Uploads one sample video straight to Bunny Stream over TUS (same mechanism as episode videos):
 * POST me/studio-application/samples for a signed ticket, TUS upload, then POST .../complete.
 */
export async function uploadSample(file: File, onProgress: (pct: number) => void): Promise<void> {
  const [res, tus] = await Promise.all([
    api.post<{ sample: ApplicationSample; upload: VideoUploadTicket }>("/me/studio-application/samples", {
      title: file.name.replace(/\.[^.]+$/, "").slice(0, 150),
      size_bytes: file.size,
    }),
    import("tus-js-client"),
  ]);
  const ticket = res.upload;
  await new Promise<void>((resolve, reject) => {
    const up = new tus.Upload(file, {
      endpoint: ticket.tus_endpoint || "https://video.bunnycdn.com/tusupload",
      retryDelays: [0, 1000, 3000, 5000, 10000, 20000],
      chunkSize: 50 * 1024 * 1024,
      headers: {
        AuthorizationSignature: ticket.signature,
        AuthorizationExpire: String(ticket.expires),
        VideoId: ticket.video_id,
        LibraryId: String(ticket.library_id),
      },
      metadata: { filetype: file.type || "video/mp4", title: ticket.title || file.name },
      storeFingerprintForResuming: false,
      onProgress: (sent, total) => onProgress(total ? Math.round((sent / total) * 100) : 0),
      onSuccess: () => resolve(),
      onError: (err: Error) => reject(err),
    });
    up.start();
  });
  await api.post(`/me/studio-application/samples/${res.sample.id}/complete`, { video_id: ticket.video_id });
}
