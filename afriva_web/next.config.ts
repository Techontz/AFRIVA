import type { NextConfig } from "next";

type RemotePattern = { protocol: "http" | "https"; hostname: string; port?: string };

// The API host serves studio uploads (posters, thumbnails), so allow it
// explicitly instead of relying on the hardcoded dev hosts below.
const apiUrl = process.env.NEXT_PUBLIC_API_URL;
const apiPatterns: RemotePattern[] = [];
if (apiUrl) {
  try {
    const u = new URL(apiUrl);
    apiPatterns.push({
      protocol: u.protocol === "http:" ? "http" : "https",
      hostname: u.hostname,
      ...(u.port ? { port: u.port } : {}),
    });
  } catch {
    console.warn(`[afriva] NEXT_PUBLIC_API_URL is not a valid URL: ${apiUrl}`);
  }
} else if (process.env.NODE_ENV === "production") {
  console.warn(
    "[afriva] NEXT_PUBLIC_API_URL is not set — the build will call http://localhost:8000/api/v1. Set it before building for production.",
  );
}

const nextConfig: NextConfig = {
  // Self-contained server.js bundle for Node hosting (cPanel/DirectAdmin "Setup Node.js App").
  output: "standalone",
  // Optional CDN pull zone in front of this site (e.g. https://afriva-web.b-cdn.net) for /_next/static and /brand.
  assetPrefix: process.env.NEXT_PUBLIC_ASSET_PREFIX || undefined,
  cacheComponents: true,
  partialPrefetching: true,
  images: {
    // Posters/backdrops come from the API (picsum seeds, studio uploads on the
    // API host, or arbitrary URLs pasted by studios), so we serve them as-is.
    unoptimized: true,
    remotePatterns: [
      ...apiPatterns,
      { protocol: "https", hostname: "picsum.photos" },
      { protocol: "https", hostname: "fastly.picsum.photos" },
      // Bunny Stream thumbnails / previews (vz-xxxx.b-cdn.net) and Bunny pull zones.
      { protocol: "https", hostname: "**.b-cdn.net" },
      { protocol: "http", hostname: "localhost", port: "8000" },
      { protocol: "http", hostname: "127.0.0.1", port: "8000" },
    ],
  },
  turbopack: {
    root: process.cwd(),
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
