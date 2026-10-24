import type { PageMeta } from "./types";

export const API_URL = (
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1"
).replace(/\/+$/, "");

export const TOKEN_KEY = "afriva_token";

export class ApiError extends Error {
  status: number;
  code: string;
  errors?: Record<string, string[]>;
  body: Record<string, unknown>;

  constructor(status: number, body: Record<string, unknown>) {
    super(
      (typeof body.message === "string" && body.message) ||
        (status === 0 ? "Cannot reach the Afriva server" : `Request failed (${status})`),
    );
    this.status = status;
    this.code = (typeof body.code === "string" && body.code) || "error";
    this.errors = body.errors as Record<string, string[]> | undefined;
    this.body = body;
  }

  /** First validation message, falling back to the main message. */
  get firstError(): string {
    if (this.errors) {
      const first = Object.values(this.errors)[0];
      if (first?.[0]) return first[0];
    }
    return this.message;
  }
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setToken(token: string | null) {
  if (typeof window === "undefined") return;
  try {
    if (token) window.localStorage.setItem(TOKEN_KEY, token);
    else window.localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* storage unavailable */
  }
  const secure = window.location.protocol === "https:" ? "; Secure" : "";
  document.cookie = token
    ? `${TOKEN_KEY}=${encodeURIComponent(token)}; Path=/; Max-Age=${60 * 60 * 24 * 30}; SameSite=Lax${secure}`
    : `${TOKEN_KEY}=; Path=/; Max-Age=0; SameSite=Lax`;
}

type Query = Record<string, string | number | boolean | null | undefined>;

export function buildQuery(query?: Query): string {
  if (!query) return "";
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null || v === "") continue;
    params.set(k, String(v));
  }
  const s = params.toString();
  return s ? `?${s}` : "";
}

export interface RequestOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  query?: Query;
  token?: string | null;
  signal?: AbortSignal;
}

/** Low-level request returning the parsed JSON envelope. */
export async function request<T = unknown>(
  path: string,
  { method = "GET", body, query, token, signal }: RequestOptions = {},
): Promise<T> {
  const headers: Record<string, string> = { Accept: "application/json" };
  const auth = token === undefined ? getToken() : token;
  if (auth) headers.Authorization = `Bearer ${auth}`;

  let payload: BodyInit | undefined;
  if (body instanceof FormData) {
    payload = body;
  } else if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}${buildQuery(query)}`, {
      method,
      headers,
      body: payload,
      signal,
      cache: "no-store",
    });
  } catch (e) {
    if ((e as Error)?.name === "AbortError") throw e;
    throw new ApiError(0, {});
  }

  const text = await res.text();
  let json: Record<string, unknown> = {};
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { message: res.ok ? undefined : text.slice(0, 200) };
    }
  }
  if (!res.ok) {
    if (res.status === 401 && auth && typeof window !== "undefined") {
      window.dispatchEvent(new CustomEvent("afriva:unauthorized"));
    }
    throw new ApiError(res.status, json);
  }
  return json as T;
}

/** Returns `data` from the `{ data, meta }` envelope. */
export async function apiGet<T>(path: string, query?: Query, signal?: AbortSignal): Promise<T> {
  const res = await request<{ data: T }>(path, { query, signal });
  return res.data;
}

export async function apiSend<T>(
  method: "POST" | "PUT" | "PATCH" | "DELETE",
  path: string,
  body?: unknown,
): Promise<T> {
  // Laravel only parses multipart bodies on POST: spoof the method.
  if (body instanceof FormData && method !== "POST") {
    body.set("_method", method);
    method = "POST";
  }
  const res = await request<{ data: T }>(path, { method, body });
  return res?.data as T;
}

export const api = {
  get: apiGet,
  post: <T>(path: string, body?: unknown) => apiSend<T>("POST", path, body),
  put: <T>(path: string, body?: unknown) => apiSend<T>("PUT", path, body),
  patch: <T>(path: string, body?: unknown) => apiSend<T>("PATCH", path, body),
  del: <T>(path: string) => apiSend<T>("DELETE", path),
  /** Full envelope (for paginated responses). */
  page: async <T>(path: string, query?: Query, signal?: AbortSignal) => {
    const res = await request<{ data: T[] | { data: T[] }; meta?: PageMeta }>(path, { query, signal });
    return normalizePage<T>(res);
  },
};

/**
 * Accepts `{data:[...], meta}` (spec), Laravel's raw paginator
 * `{data:{data:[...], current_page...}}`, or a plain array, and returns a
 * uniform `{ items, meta }`.
 */
export function normalizePage<T>(res: unknown): { items: T[]; meta: PageMeta } {
  const fallbackMeta = (n: number): PageMeta => ({ current_page: 1, last_page: 1, total: n });
  if (Array.isArray(res)) return { items: res as T[], meta: fallbackMeta(res.length) };
  const r = res as { data?: unknown; meta?: Partial<PageMeta> } & Partial<PageMeta>;
  if (Array.isArray(r?.data)) {
    const items = r.data as T[];
    const m = r.meta ?? r;
    return {
      items,
      meta: {
        current_page: Number(m.current_page ?? 1),
        last_page: Number(m.last_page ?? 1),
        total: Number(m.total ?? items.length),
        per_page: m.per_page ? Number(m.per_page) : undefined,
      },
    };
  }
  if (r?.data && typeof r.data === "object") return normalizePage<T>(r.data);
  return { items: [], meta: fallbackMeta(0) };
}

/** Normalises list-ish `data` (array or paginator) into an array. */
export function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && Array.isArray((data as { data?: unknown }).data)) {
    return (data as { data: T[] }).data;
  }
  return [];
}

export function errorMessage(e: unknown): string {
  if (e instanceof ApiError) return e.firstError;
  if (e instanceof Error) return e.message;
  return "Something went wrong";
}
