"use client";

import { useEffect, useRef, useState } from "react";
import { useLocale } from "@/i18n/client";
import { Spinner } from "../ui/Feedback";
import { useTheme } from "../ThemeToggle";

/** Google OAuth web client id. Empty means the feature stays hidden. */
export const GOOGLE_CLIENT_ID = (process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? "").trim();

const GSI_SRC = "https://accounts.google.com/gsi/client";

type GsiButtonOptions = {
  type?: "standard" | "icon";
  theme?: "outline" | "filled_blue" | "filled_black";
  size?: "large" | "medium" | "small";
  text?: "signin_with" | "signup_with" | "continue_with" | "signin";
  shape?: "rectangular" | "pill" | "circle" | "square";
  logo_alignment?: "left" | "center";
  width?: number;
  locale?: string;
};

type GsiId = {
  initialize: (config: {
    client_id: string;
    callback: (res: { credential?: string }) => void;
    auto_select?: boolean;
    cancel_on_tap_outside?: boolean;
    use_fedcm_for_button?: boolean;
  }) => void;
  renderButton: (parent: HTMLElement, options: GsiButtonOptions) => void;
  disableAutoSelect: () => void;
};

declare global {
  interface Window {
    google?: { accounts?: { id?: GsiId } };
  }
}

let gsiPromise: Promise<GsiId> | null = null;

/** Loads Google Identity Services once per page load. */
function loadGsi(): Promise<GsiId> {
  if (window.google?.accounts?.id) return Promise.resolve(window.google.accounts.id);
  if (gsiPromise) return gsiPromise;
  gsiPromise = new Promise<GsiId>((resolve, reject) => {
    const done = () => (window.google?.accounts?.id ? resolve(window.google.accounts.id) : reject(new Error("gsi")));
    let script = document.querySelector<HTMLScriptElement>(`script[src="${GSI_SRC}"]`);
    if (!script) {
      script = document.createElement("script");
      script.src = GSI_SRC;
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
    script.addEventListener("load", done, { once: true });
    script.addEventListener("error", () => reject(new Error("gsi")), { once: true });
  }).catch((e) => {
    gsiPromise = null; // allow a retry on the next mount
    throw e;
  });
  return gsiPromise;
}

// The latest credential handler, so GSI is initialized only once per page.
let onCredentialRef: ((idToken: string) => void) | null = null;
let initializedFor: string | null = null;

/**
 * Google's official "Continue with Google" button. Renders nothing when
 * NEXT_PUBLIC_GOOGLE_CLIENT_ID is not configured. No One Tap prompt.
 */
export function GoogleSignIn({
  onCredential,
  busy,
  busyLabel,
}: {
  onCredential: (idToken: string) => void;
  busy?: boolean;
  busyLabel?: string;
}) {
  const locale = useLocale();
  const [theme] = useTheme();
  const wrapRef = useRef<HTMLDivElement>(null);
  const btnRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);

  useEffect(() => {
    onCredentialRef = onCredential;
  }, [onCredential]);

  // Track the form width (Google accepts 200 to 400 px).
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const measure = () => setWidth(Math.round(Math.min(400, Math.max(200, el.clientWidth))));
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    if (!GOOGLE_CLIENT_ID || !width) return;
    let alive = true;
    loadGsi()
      .then((gsi) => {
        if (!alive || !btnRef.current) return;
        if (initializedFor !== GOOGLE_CLIENT_ID) {
          gsi.initialize({
            client_id: GOOGLE_CLIENT_ID,
            callback: (res) => {
              if (res.credential) onCredentialRef?.(res.credential);
            },
            auto_select: false,
            cancel_on_tap_outside: true,
          });
          initializedFor = GOOGLE_CLIENT_ID;
        }
        btnRef.current.innerHTML = "";
        gsi.renderButton(btnRef.current, {
          type: "standard",
          theme: theme === "dark" ? "filled_black" : "outline",
          size: "large",
          text: "continue_with",
          shape: "pill",
          logo_alignment: "center",
          width,
          locale,
        });
      })
      .catch(() => {
        /* script blocked or offline: the email form still works */
      });
    return () => {
      alive = false;
    };
  }, [width, theme, locale]);

  if (!GOOGLE_CLIENT_ID) return null;

  return (
    <div ref={wrapRef} className="relative w-full" data-testid="google-signin">
      <div
        ref={btnRef}
        className={busy ? "pointer-events-none opacity-40 transition-opacity" : "transition-opacity"}
        // "light" matches Google's iframe, so the browser keeps the frame transparent on our dark pages
        // (a mismatched colour scheme makes it paint an opaque white strip behind the button).
        style={{ minHeight: 44, display: "flex", justifyContent: "center", colorScheme: "light" }}
      />
      {busy && (
        <div className="absolute inset-0 grid place-items-center" role="status" aria-label={busyLabel}>
          <Spinner size={20} className="text-primary" />
        </div>
      )}
    </div>
  );
}
