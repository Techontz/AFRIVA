// Types mirroring SPEC.md §4/§6. Fields not explicitly in the spec are optional.

export type Role = "viewer" | "company" | "super_admin";
export type Badge = "hot" | "new" | "vip";
export type PlanType = "weekly" | "monthly" | "yearly" | "episodes" | "coins";
export type PaymentMethodType = "mobile_money" | "card" | "bank";
export type PaymentStatus = "pending" | "success" | "failed" | "cancelled" | "refunded";
export type StaffRole = "owner" | "editor" | "reviewer" | "finance";
export type StaffPermission =
  | "dashboard" | "content" | "review" | "publish" | "creators" | "reports"
  | "finance" | "analytics" | "users" | "settings" | "staff" | "audit";
/** SPEC §8.5: Rasimu · Imetumwa · Inakaguliwa · Marekebisho · Imeidhinishwa · Imekataliwa */
export type ReviewStatus = "draft" | "submitted" | "in_review" | "changes_requested" | "approved" | "rejected";
export type AccessMode = "coins_or_vip" | "vip_only" | "coins_only";
export type AgeRating = "all" | "7+" | "13+" | "16+" | "18+";
export type VideoStatus = "uploaded" | "processing" | "ready" | "failed";
export type EpisodeAccess = "free" | "unlocked" | "locked";

export interface Envelope<T> {
  data: T;
  meta?: PageMeta & Record<string, unknown>;
  message?: string;
}

export interface PageMeta {
  current_page: number;
  last_page: number;
  total: number;
  per_page?: number;
}

export interface Paginated<T> {
  data: T[];
  meta: PageMeta;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
  sort_order?: number;
  dramas_count?: number;
}

export interface CompanyRef {
  id: number;
  name: string;
  slug: string;
}

export interface Drama {
  id: number;
  slug: string;
  title: string;
  synopsis: string;
  poster_url: string;
  backdrop_url: string;
  total_episodes: number;
  free_episodes: number;
  coins_per_episode: number;
  badge: Badge | null;
  views: number;
  categories: Category[];
  tags: string[];
  company: CompanyRef | null;
  is_favorite: boolean;
  trailer_url?: string | null;
  age_rating?: AgeRating | null;
  access_mode?: AccessMode;
  total_duration_seconds?: number;
  /** Continue watching (home section `continue_watching`). */
  resume?: ResumeInfo;
  // Present on admin/studio payloads
  status?: "draft" | "published";
  publish_at?: string | null;
  is_scheduled?: boolean;
  is_live?: boolean;
  review_status?: ReviewStatus;
  review_notes?: string | null;
  submitted_at?: string | null;
  reviewed_at?: string | null;
  rights_declared_at?: string | null;
  episodes_count?: number;
  pending_episodes_count?: number;
  is_featured?: boolean;
  language?: string | null;
  release_date?: string | null;
  created_at?: string;
  earnings?: number;
}

export interface Episode {
  id: number;
  number: number;
  title: string | null;
  duration_seconds: number | null;
  thumbnail_url: string | null;
  is_free: boolean;
  is_unlocked: boolean;
  access?: EpisodeAccess;
  price_coins?: number;
  vip_only?: boolean;
  subtitle_url?: string | null;
  sources?: VideoSource[];
  // admin/studio only
  video_url?: string | null;
  views?: number;
  video_status?: VideoStatus;
  video_error?: string | null;
  renditions?: string[];
  source_size?: number | null;
  is_free_override?: boolean | null;
  review_status?: ReviewStatus;
  review_notes?: string | null;
  playback_verified_at?: string | null;
}

export interface ResumeInfo {
  episode_id: number | null;
  episode_number: number;
  progress_seconds: number;
  duration_seconds: number;
  updated_at?: string | null;
}

export interface VideoSource {
  quality: "auto" | "480p" | "720p" | "1080p" | string;
  label: string;
  url: string;
  type: "hls" | "mp4";
}

export interface ContentReview {
  id: number;
  drama_id: number;
  episode_id: number | null;
  episode_number?: number | null;
  action: string;
  from_status: ReviewStatus | null;
  to_status: ReviewStatus | null;
  notes: string | null;
  user?: { id: number; name: string; role: Role } | null;
  created_at: string;
}

/** Admin/studio drama detail: episodes with review/processing state + review history. */
export interface ManagedDrama extends Drama {
  episodes: Episode[];
  reviews: ContentReview[];
  company_agreement_accepted?: boolean;
}

export interface DramaDetail extends Drama {
  episodes: Episode[];
  related: Drama[];
}

export interface HomeSection {
  key: string;
  title: string;
  layout: "row" | "ranking" | "grid" | "continue";
  category?: string;
  dramas: Drama[];
}

export interface HomeData {
  banners: Drama[];
  sections: HomeSection[];
}

export interface PlayData {
  video_url: string;
  sources: VideoSource[];
  subtitle_url: string | null;
  resume_seconds: number;
  /** Send back with POST /events (SPEC §8.3). */
  session_id: string;
  episode: Episode;
  drama?: { id: number; slug: string; title: string; total_episodes: number; free_episodes: number; poster_url: string };
  next_episode_id: number | null;
  prev_episode_id: number | null;
}

export interface UnlockInfo {
  episode_id?: number;
  coins_required: number;
  user_coins: number;
  can_use_pack: boolean;
  can_use_coins?: boolean;
  can_use_vip?: boolean;
  vip_only?: boolean;
  episodes_remaining?: number;
  requires_login?: boolean;
}

export type PlayerEventType = "start" | "heartbeat" | "pause" | "complete" | "error" | "quality";

export interface PlayerEvent {
  session_id: string;
  episode_id: number;
  type: PlayerEventType;
  position_seconds?: number;
  watched_seconds?: number;
  duration_seconds?: number;
  quality?: string;
  error_code?: string;
}

export interface Plan {
  id: number;
  name: string;
  type: PlanType;
  price: number;
  currency: string;
  duration_days: number | null;
  episode_quota: number | null;
  coins: number | null;
  bonus_coins: number | null;
  description: string | null;
  features: string[] | null;
  is_popular: boolean;
  is_active?: boolean;
  sort_order?: number;
}

export interface PaymentMethod {
  id: number;
  code: string;
  name: string;
  type: PaymentMethodType;
  logo_url: string | null;
  color: string | null;
  is_enabled?: boolean;
  is_integrated?: boolean;
  /** Only available methods may be offered at checkout (SPEC §8.4). */
  is_available?: boolean;
  fee_percent?: number;
  tested_at?: string | null;
  sort_order?: number;
  config?: Record<string, string | null> | null;
}

export interface Subscription {
  id: number;
  plan_id?: number;
  plan?: Plan | null;
  type: PlanType;
  starts_at: string;
  ends_at: string | null;
  episodes_remaining: number | null;
  status: "active" | "expired" | "cancelled";
}

export interface User {
  id: number;
  name: string;
  email: string | null;
  phone: string | null;
  role: Role;
  staff_role?: StaffRole | null;
  permissions?: StaffPermission[];
  coins: number;
  avatar_url: string | null;
  status?: "active" | "suspended";
  company_id?: number | null;
  company?: (CompanyRef & Partial<Company>) | null;
  active_subscription?: Subscription | null;
  created_at?: string;
}

export interface AuthPayload {
  token: string;
  user: User;
}

export interface Payment {
  id: number;
  reference: string;
  amount: number;
  currency: string;
  status: PaymentStatus;
  payment_method_code?: string;
  payment_method?: string | PaymentMethod | null;
  phone?: string | null;
  provider_reference?: string | null;
  receipt_number?: string | null;
  fee_amount?: number;
  refunded_amount?: number;
  refunded_at?: string | null;
  plan?: Plan | null;
  plan_id?: number;
  user?: Pick<User, "id" | "name" | "email" | "phone"> | null;
  paid_at?: string | null;
  created_at?: string;
}

export interface CheckoutResult {
  payment: Pick<Payment, "reference" | "status" | "amount" | "currency">;
  message: string;
  next_action: "await_ussd" | "redirect" | "none";
  redirect_url?: string | null;
}

export interface HistoryItem {
  id?: number;
  drama: Drama;
  episode?: Pick<Episode, "id" | "number" | "title"> | null;
  episode_id?: number;
  progress_seconds: number;
  updated_at?: string;
}

export interface FeedItem {
  drama: Drama;
  episode: Episode & { video_url: string };
}

export interface Company {
  id: number;
  name: string;
  slug: string;
  logo_url: string | null;
  email: string | null;
  phone: string | null;
  country: string | null;
  revenue_share_percent: number | string;
  status: "pending" | "active" | "suspended";
  agreement_accepted?: boolean;
  agreement_accepted_at?: string | null;
  agreement_version?: string | null;
  description: string | null;
  dramas_count?: number;
  owner?: Pick<User, "id" | "name" | "email"> | null;
  created_at?: string;
}

export interface Payout {
  id: number;
  company_id?: number;
  company?: CompanyRef | null;
  amount: number;
  status: "pending" | "paid";
  reference: string | null;
  paid_at: string | null;
  notes: string | null;
  created_at?: string;
}

export interface Earning {
  id: number;
  drama_id: number | null;
  drama?: Pick<Drama, "id" | "title" | "slug"> | null;
  source: "subscription_pool" | "episode_pack" | "coins";
  amount: number;
  period_date: string;
  created_at?: string;
}

export interface ChartPoint {
  date: string;
  value: number;
}

export type Settings = Record<string, string | number | boolean | null>;

export interface Receipt {
  receipt_number: string | null;
  reference: string;
  provider_reference: string | null;
  status: PaymentStatus;
  issued_at: string | null;
  customer: { name: string | null; email: string | null; phone: string | null };
  item: { name: string | null; type: PlanType | null; description: string | null; delivered: string | null };
  payment_method: { code: string; name: string };
  amount: number;
  refunded_amount: number;
  currency: string;
  seller: { name: string; email: string | null };
}

export type CoinTransactionType = "purchase" | "bonus" | "unlock" | "admin_adjust" | "refund";

export interface CoinTransaction {
  id: number;
  user_id?: number;
  amount: number;
  balance_after: number;
  type: CoinTransactionType;
  description: string | null;
  payment_id: number | null;
  episode?: { id: number; number: number; drama: { id: number; title: string; slug: string } | null } | null;
  created_at: string;
}

export interface CreatorAgreement {
  version: string;
  text: string;
  accepted: boolean;
  accepted_at: string | null;
  accepted_version?: string | null;
  revenue_share_percent: number;
  company_status: Company["status"];
}

export type ReportReason = "copyright" | "inappropriate" | "misleading" | "other";
