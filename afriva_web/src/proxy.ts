import { NextResponse, type NextRequest } from "next/server";
import { DEFAULT_LOCALE, LANG_COOKIE, isLocale } from "./i18n/config";
import { PORTAL_URLS, portalForHost, type Portal } from "./lib/portals";

// Pages a portal host may serve besides its own area (sign-in and legal pages).
const SHARED_ON_PORTAL = /^\/(login|apply|info)(\/|$)/;

/**
 * Admin and Studio live on their own hosts when configured; the main site
 * redirects those areas there and portal hosts only serve their own area.
 * URLs stay unprefixed (`/browse`); the language cookie picks which prerendered
 * `/[lang]` tree serves them, so both languages stay fully static/cacheable.
 */
export function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;
  const host = request.headers.get("x-forwarded-host") ?? request.headers.get("host") ?? "";
  const bare = pathname.replace(/^\/(en|sw)(?=\/|$)/, "") || "/";
  const area = /^\/(admin|studio)(\/|$)/.exec(bare)?.[1] as Portal | undefined;
  const portal = portalForHost(host);

  if (area && area !== portal && PORTAL_URLS[area]) {
    return NextResponse.redirect(`${PORTAL_URLS[area]}${bare}${search}`, 307);
  }
  if (portal && !area && !SHARED_ON_PORTAL.test(bare)) {
    return NextResponse.redirect(`${PORTAL_URLS[portal]}/${portal}`, 307);
  }

  const cookie = request.cookies.get(LANG_COOKIE)?.value;
  const prefixed = /^\/(en|sw)(?=\/|$)/.exec(pathname)?.[1];
  if (prefixed) {
    // Internal links are unprefixed, so a direct /sw visit has to set the language they will use.
    if (cookie === prefixed) return;
    const res = NextResponse.next();
    res.cookies.set(LANG_COOKIE, prefixed, { path: "/", maxAge: 60 * 60 * 24 * 365, sameSite: "lax" });
    return res;
  }
  const locale = isLocale(cookie) ? cookie : DEFAULT_LOCALE;
  const url = request.nextUrl.clone();
  url.pathname = `/${locale}${pathname === "/" ? "" : pathname}`;
  return NextResponse.rewrite(url);
}

export const config = {
  matcher: ["/((?!_next/|api/|favicon\\.ico|icon\\.svg|.*\\.[a-zA-Z0-9]{2,5}$).*)"],
};
