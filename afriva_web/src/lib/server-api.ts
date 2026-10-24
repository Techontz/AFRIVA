import { connection } from "next/server";
import { API_URL, buildQuery, normalizePage } from "./api";
import type { PageMeta } from "./types";

type Query = Record<string, string | number | undefined | null>;

/**
 * Server-side fetch of public API data.
 *
 * - Defers to request time (`connection()`), so pages never bake an
 *   "API down" result into the build output. Callers must render inside
 *   `<Suspense>`.
 * - Successful (200) responses are cached in the Next data cache for
 *   `revalidate` seconds.
 * - Never throws: returns `null` when the API is unreachable or errors, so
 *   pages can render a graceful empty/error state.
 */
async function fetchEnvelope<T>(path: string, query?: Query, revalidate = 60): Promise<T | null> {
  await connection();
  try {
    const res = await fetch(`${API_URL}${path}${buildQuery(query)}`, {
      headers: { Accept: "application/json" },
      next: { revalidate },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

export async function serverGet<T>(path: string, query?: Query, revalidate = 60): Promise<T | null> {
  const json = await fetchEnvelope<{ data: T }>(path, query, revalidate);
  return json ? json.data : null;
}

export async function serverPage<T>(
  path: string,
  query?: Query,
  revalidate = 60,
): Promise<{ items: T[]; meta: PageMeta } | null> {
  const json = await fetchEnvelope<unknown>(path, query, revalidate);
  return json ? normalizePage<T>(json) : null;
}

/** Like serverGet but reports the HTTP status (0 = unreachable) so pages can 404 properly. */
export async function serverGetWithStatus<T>(
  path: string,
  query?: Query,
  revalidate = 60,
): Promise<{ data: T | null; status: number }> {
  await connection();
  try {
    const res = await fetch(`${API_URL}${path}${buildQuery(query)}`, {
      headers: { Accept: "application/json" },
      next: { revalidate },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return { data: null, status: res.status };
    const json = (await res.json()) as { data: T };
    return { data: json.data, status: res.status };
  } catch {
    return { data: null, status: 0 };
  }
}
