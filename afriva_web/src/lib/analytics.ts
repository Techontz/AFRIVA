import { randomId, request } from "./api";
import type { PlayerEvent } from "./types";

const DEVICE_KEY = "afriva_device_id";
let memoryDevice: string | null = null;

/**
 * Stable anonymous id sent as X-Device-Id so guests count once in unique viewers / DAU (SPEC §8.3).
 * Kept in localStorage; falls back to an in-memory id when storage is blocked.
 */
export function deviceId(): string {
  try {
    const saved = window.localStorage.getItem(DEVICE_KEY);
    if (saved && /^[A-Za-z0-9_-]{8,64}$/.test(saved)) return saved;
    const fresh = randomId().replace(/[^A-Za-z0-9_-]/g, "").slice(0, 64);
    window.localStorage.setItem(DEVICE_KEY, fresh);
    return fresh;
  } catch {
    memoryDevice ??= randomId().replace(/[^A-Za-z0-9_-]/g, "").slice(0, 64);
    return memoryDevice;
  }
}

/** POST /events. Never throws: analytics must not break playback. */
export function sendPlayerEvents(events: PlayerEvent[]): void {
  if (!events.length || typeof window === "undefined") return;
  request("/events", {
    method: "POST",
    body: { events },
    headers: { "X-Device-Id": deviceId() },
    keepalive: true,
  }).catch(() => {});
}
