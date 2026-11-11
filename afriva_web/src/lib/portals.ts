import type { Role } from "./types";

// Each area can live on its own host (admin.afriva.co.tz, studio.afriva.co.tz).
// When a URL is not configured the area stays on the current host (local dev).
const clean = (u?: string) => (u ? u.replace(/\/+$/, "") : "");

export const SITE_URL = clean(process.env.NEXT_PUBLIC_SITE_URL);
export const ADMIN_URL = clean(process.env.NEXT_PUBLIC_ADMIN_URL);
export const STUDIO_URL = clean(process.env.NEXT_PUBLIC_STUDIO_URL);

export type Portal = "admin" | "studio";

export const PORTAL_URLS: Record<Portal, string> = { admin: ADMIN_URL, studio: STUDIO_URL };

export function hostOf(url: string): string | null {
  try {
    return url ? new URL(url).host : null;
  } catch {
    return null;
  }
}

/** The portal a host serves (admin.afriva.co.tz -> "admin"), or null for the main site. */
export function portalForHost(host: string): Portal | null {
  for (const p of Object.keys(PORTAL_URLS) as Portal[]) {
    if (PORTAL_URLS[p] && hostOf(PORTAL_URLS[p]) === host) return p;
  }
  return null;
}

/** Area root path for a role: "/admin", "/studio" or "/". */
export function portalPathForRole(role: Role | undefined): string {
  if (role === "super_admin") return "/admin";
  if (role === "company") return "/studio";
  return "/";
}

/** `path` on the host that serves the role's area (absolute when that host is configured). */
export function roleUrl(role: Role | undefined, path: string): string {
  const base = role === "super_admin" ? ADMIN_URL : role === "company" ? STUDIO_URL : SITE_URL;
  return base ? base + path : path;
}

export function siteUrl(path: string): string {
  return SITE_URL ? SITE_URL + path : path;
}
