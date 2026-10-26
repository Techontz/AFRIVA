/**
 * Shared helpers and API shapes for the Studio (creators) and Admin (staff) portals.
 * See SPEC.md §8.5–8.7.
 */
import type { Tone } from "@/components/ui/Feedback";
import type {
  AccessMode,
  AgeRating,
  ChartPoint,
  Payment,
  Receipt,
  ReviewStatus,
  StaffPermission,
  StaffRole,
  User,
  VideoSource,
  VideoStatus,
} from "./types";

// ---- Labels (English keys; Kiswahili in lib/sw/admin.ts) --------------------------------

/** Rasimu · Imetumwa · Inakaguliwa · Marekebisho · Imeidhinishwa · Imekataliwa */
export const REVIEW_LABEL: Record<ReviewStatus, string> = {
  draft: "Draft",
  submitted: "Submitted",
  in_review: "In review",
  changes_requested: "Changes requested",
  approved: "Approved",
  rejected: "Rejected",
};

export const REVIEW_TONE: Record<ReviewStatus, Tone> = {
  draft: "neutral",
  submitted: "info",
  in_review: "gold",
  changes_requested: "brand",
  approved: "success",
  rejected: "danger",
};

export const VIDEO_STATUS_LABEL: Record<VideoStatus, string> = {
  uploaded: "Uploaded",
  processing: "Processing",
  ready: "Ready",
  failed: "Failed",
};

export const VIDEO_STATUS_TONE: Record<VideoStatus, Tone> = {
  uploaded: "neutral",
  processing: "info",
  ready: "success",
  failed: "danger",
};

export const ACCESS_MODE_LABEL: Record<AccessMode, string> = {
  coins_or_vip: "Coins or VIP",
  vip_only: "VIP only",
  coins_only: "Coins only",
};

export const AGE_RATINGS: AgeRating[] = ["all", "7+", "13+", "16+", "18+"];
export const AGE_RATING_LABEL: Record<AgeRating, string> = {
  all: "All ages",
  "7+": "7+",
  "13+": "13+",
  "16+": "16+",
  "18+": "18+",
};

export const STAFF_ROLE_LABEL: Record<StaffRole, string> = {
  owner: "Owner",
  editor: "Editor",
  reviewer: "Reviewer",
  finance: "Finance",
};

export const PERMISSION_LABEL: Record<StaffPermission, string> = {
  dashboard: "Overview",
  content: "Content",
  review: "Review",
  publish: "Publishing",
  creators: "Creators",
  reports: "Reports",
  finance: "Finance",
  analytics: "Analytics",
  users: "Users",
  settings: "Settings",
  staff: "Staff",
  audit: "Audit log",
};

export const REVIEW_ACTION_LABEL: Record<string, string> = {
  submitted: "Submitted for review",
  resubmitted: "Resubmitted after changes",
  review_started: "Review started",
  playback_verified: "Playback checked",
  approve: "Approved",
  request_changes: "Changes requested",
  reject: "Rejected",
  published: "Published",
  scheduled: "Scheduled",
  unpublished: "Unpublished",
};

/** Creators may edit only drafts and series sent back for changes (409 locked_for_review otherwise). */
export function isCreatorEditable(status: ReviewStatus | undefined | null): boolean {
  return !status || status === "draft" || status === "changes_requested";
}

export function hasPerm(user: User | null | undefined, perm: StaffPermission): boolean {
  return !!user?.permissions?.includes(perm);
}

// ---- Formatting -------------------------------------------------------------------------

/** "—" for empty/zero-less values so no number is ever invented. */
export const DASH = "—";

export function pct(v: number | null | undefined, digits = 0): string {
  if (v === null || v === undefined || Number.isNaN(v)) return DASH;
  return `${(v * 100).toFixed(digits)}%`;
}

/** Watch time: "3h 20m", "45m", "30s". */
export function watchTime(seconds: number | null | undefined): string {
  const s = Math.max(0, Math.round(Number(seconds ?? 0)));
  if (!s) return DASH;
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h) return `${h.toLocaleString()}h ${m}m`;
  if (m) return `${m}m`;
  return `${s}s`;
}

export function bytes(n: number | null | undefined): string {
  if (!n) return DASH;
  const units = ["B", "KB", "MB", "GB", "TB"];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(v >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
}

/** ISO → value for <input type="datetime-local"> in local time. */
export function toLocalInput(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

// ---- API shapes -------------------------------------------------------------------------

export interface AdminVideo {
  id: number;
  number: number;
  title: string | null;
  drama: { id: number; title: string; slug: string; poster_url: string | null; company: string | null } | null;
  thumbnail_url: string | null;
  duration_seconds: number;
  is_uploaded: boolean;
  video_status: VideoStatus;
  video_error: string | null;
  renditions: string[];
  source_size: number | null;
  subtitle_url: string | null;
  review_status: ReviewStatus;
  playback_verified_at: string | null;
  sources: VideoSource[];
  updated_at: string | null;
}

export interface SeriesAnalyticsRow {
  drama_id: number;
  title: string;
  slug: string;
  poster_url: string | null;
  revenue_gross: number;
  creator_earnings: number;
  views: number;
  unique_viewers: number;
  watch_seconds: number;
  completion_rate: number;
}

export interface Period {
  days: number;
  from: string;
  to: string;
}

export interface CostAlert {
  level: "warning" | "danger";
  code: string;
  message: string;
  total?: number;
  limit?: number;
}

export interface AnalyticsOverview {
  period: Period;
  revenue: {
    gross: number;
    refunds: number;
    fees: number;
    net: number;
    streaming_cost: number;
    streaming_cost_is_estimate: boolean;
    operating_costs: number;
    net_after_costs: number;
    by_type: { type: string; value: number }[];
    chart: { date: string; gross: number; net: number }[];
  };
  audience: {
    views: number;
    unique_viewers: number;
    watch_seconds: number;
    avg_watch_seconds_per_viewer: number;
    sessions: number;
    completion_rate: number;
    returning_viewers: number;
    retention_rate: number;
    playback_errors: number;
    views_chart: ChartPoint[];
    watch_time_chart: ChartPoint[];
  };
  active_users: { dau: number; dau_avg: number; mau: number; chart: ChartPoint[] };
  coins: {
    purchased: number;
    bonus: number;
    spent: number;
    refunded: number;
    admin_adjusted: number;
    outstanding_balance: number;
    chart: { date: string; bought: number; spent: number }[];
  };
  payments: {
    attempts: number;
    success: number;
    failed: number;
    pending: number;
    cancelled: number;
    success_rate: number;
    by_method: { method: string; name: string; attempts: number; success: number; failed: number; amount: number }[];
  };
  series: SeriesAnalyticsRow[];
  alerts: CostAlert[];
}

export interface DramaAnalytics {
  drama: { id: number; title: string; slug: string; poster_url: string | null; free_episodes: number; coins_per_episode: number };
  period: Period;
  totals: { views: number; unique_viewers: number; watch_seconds: number; revenue_gross: number };
  episodes: {
    episode_id: number;
    number: number;
    title: string | null;
    is_free: boolean;
    views: number;
    unique_viewers: number;
    reach_rate: number;
    watch_seconds: number;
    completion_rate: number;
    avg_percent_watched: number;
    revenue_gross: number;
  }[];
  drop_off: { from_percent: number; to_percent: number; sessions: number }[];
}

export interface OperatingCostRow {
  id: number;
  period: string;
  category: "streaming" | "storage" | "hosting" | "payments" | "other";
  amount: number;
  notes: string | null;
  created_by: string | null;
  created_at: string | null;
}

export interface AuditEntry {
  id: number;
  action: string;
  subject_type: string | null;
  subject_id: number | null;
  summary: string | null;
  changes: Record<string, unknown> | null;
  ip: string | null;
  user: { id: number; name: string; email: string | null; staff_role: StaffRole | null } | null;
  created_at: string;
}

export interface ContentReportRow {
  id: number;
  reason: "copyright" | "inappropriate" | "misleading" | "other";
  details: string | null;
  contact: string | null;
  status: "open" | "resolved" | "dismissed";
  drama: { id: number; title: string; slug: string; poster_url: string | null; status: string } | null;
  episode_number: number | null;
  user: { id: number; name: string; email: string | null } | null;
  resolution_notes: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  created_at: string;
}

export interface PaymentDetail {
  payment: Payment;
  refunds: { id: number; amount: number; reason: string | null; status: string; processed_by: string | null; created_at: string }[];
  receipt: Receipt | null;
  net_amount: number;
  meta: Record<string, unknown> | null;
}

export const REPORT_REASON_LABEL: Record<ContentReportRow["reason"], string> = {
  copyright: "Copyright infringement",
  inappropriate: "Inappropriate content",
  misleading: "Misleading",
  other: "Other",
};

export const COST_CATEGORY_LABEL: Record<OperatingCostRow["category"], string> = {
  streaming: "Streaming / CDN",
  storage: "Storage",
  hosting: "Hosting",
  payments: "Payment fees",
  other: "Other",
};
