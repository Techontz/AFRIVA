// Types mirroring SPEC.md §4/§6. Fields not explicitly in the spec are optional.

export type Role = "viewer" | "company" | "super_admin";
export type Badge = "hot" | "new" | "vip";
export type PlanType = "weekly" | "monthly" | "yearly" | "episodes" | "coins";
export type PaymentMethodType = "mobile_money" | "card" | "bank";
export type PaymentStatus = "pending" | "success" | "failed" | "cancelled";

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
  // Present on admin/studio payloads
  status?: "draft" | "published";
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
  // admin/studio only
  video_url?: string | null;
  views?: number;
}

export interface DramaDetail extends Drama {
  episodes: Episode[];
  related: Drama[];
}

export interface HomeSection {
  key: string;
  title: string;
  layout: "row" | "ranking" | "grid";
  dramas: Drama[];
}

export interface HomeData {
  banners: Drama[];
  sections: HomeSection[];
}

export interface PlayData {
  video_url: string;
  episode: Episode;
  next_episode_id: number | null;
  prev_episode_id: number | null;
}

export interface UnlockInfo {
  coins_required: number;
  user_coins: number;
  can_use_pack: boolean;
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
  status: "active" | "suspended";
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
