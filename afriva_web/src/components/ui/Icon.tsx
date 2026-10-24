import type { SVGProps } from "react";

// Minimal stroke icon set (24x24, currentColor) drawn for Afriva.
const paths = {
  search: <><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></>,
  menu: <path d="M4 7h16M4 12h16M4 17h16" />,
  headset: <><path d="M4 14v-2a8 8 0 0 1 16 0v2" /><rect x="3" y="14" width="4" height="6" rx="1.5" /><rect x="17" y="14" width="4" height="6" rx="1.5" /><path d="M19 20a3 3 0 0 1-3 2h-3" /></>,
  x: <path d="M6 6l12 12M18 6 6 18" />,
  "chevron-left": <path d="m15 18-6-6 6-6" />,
  "chevron-right": <path d="m9 18 6-6-6-6" />,
  "chevron-down": <path d="m6 9 6 6 6-6" />,
  "chevron-up": <path d="m18 15-6-6-6 6" />,
  play: <path d="M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5Z" fill="currentColor" stroke="none" />,
  pause: <><rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor" stroke="none" /><rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor" stroke="none" /></>,
  plus: <path d="M12 5v14M5 12h14" />,
  minus: <path d="M5 12h14" />,
  check: <path d="m5 12.5 4.5 4.5L19 7.5" />,
  lock: <><rect x="5" y="11" width="14" height="10" rx="2" /><path d="M8 11V7a4 4 0 0 1 8 0v4" /></>,
  crown: <path d="M3 8l4.5 4L12 5l4.5 7L21 8l-2 11H5L3 8Z" />,
  coin: <><circle cx="12" cy="12" r="9" /><path d="M14.8 9.2A3 3 0 0 0 12 8c-1.7 0-3 .9-3 2s1.3 1.7 3 2 3 .9 3 2-1.3 2-3 2a3 3 0 0 1-2.8-1.2M12 6.5V8m0 8v1.5" /></>,
  bookmark: <path d="M6 4h12v17l-6-4-6 4V4Z" />,
  "bookmark-filled": <path d="M6 4h12v17l-6-4-6 4V4Z" fill="currentColor" />,
  eye: <><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" /><circle cx="12" cy="12" r="3" /></>,
  home: <path d="M3 11 12 4l9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-9Z" />,
  grid: <><rect x="4" y="4" width="7" height="7" rx="1.5" /><rect x="13" y="4" width="7" height="7" rx="1.5" /><rect x="4" y="13" width="7" height="7" rx="1.5" /><rect x="13" y="13" width="7" height="7" rx="1.5" /></>,
  trophy: <path d="M8 4h8v5a4 4 0 0 1-8 0V4ZM8 6H4.5a3 3 0 0 0 3.5 4M16 6h3.5a3 3 0 0 1-3.5 4M12 13v4m-4 3h8l-1-3H9l-1 3Z" />,
  user: <><circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" /></>,
  users: <><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6 6 0 0 1 3.5 6" /></>,
  logout: <path d="M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 16l-4-4 4-4M6 12h10" />,
  settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" /></>,
  upload: <path d="M12 16V4m-5 5 5-5 5 5M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3" />,
  download: <path d="M12 4v12m-5-5 5 5 5-5M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3" />,
  trash: <path d="M4 7h16M10 11v6m4-6v6M6 7l1 13h10l1-13M9 7V4h6v3" />,
  edit: <path d="M4 20h4L19 9l-4-4L4 16v4ZM13.5 6.5l4 4" />,
  building: <path d="M4 21V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v16M15 9h4a1 1 0 0 1 1 1v11M2 21h20M8 8h3m-3 4h3m-3 4h3" />,
  film: <><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M7 4v16M17 4v16M3 9h4m10 0h4M3 15h4m10 0h4" /></>,
  card: <><rect x="2.5" y="5" width="19" height="14" rx="2" /><path d="M2.5 10h19M6 15h4" /></>,
  wallet: <path d="M4 7a2 2 0 0 1 2-2h11v4M4 7v11a2 2 0 0 0 2 2h14V9H6a2 2 0 0 1-2-2Zm12 7h.01" />,
  phone: <><rect x="7" y="2.5" width="10" height="19" rx="2" /><path d="M11 18.5h2" /></>,
  bank: <path d="M3 10 12 4l9 6M5 10v8m4.5-8v8m5-8v8M19 10v8M3 21h18" />,
  tag: <path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9-9-9Zm4.5-4.5h.01" />,
  layers: <path d="m12 3 9 5-9 5-9-5 9-5Zm-9 9 9 5 9-5M3 16l9 5 9-5" />,
  chart: <path d="M4 20V4m0 16h16M8 16v-4m4 4V8m4 8v-6" />,
  globe: <><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" /></>,
  "arrow-up": <path d="M12 19V5m-6 6 6-6 6 6" />,
  "arrow-down": <path d="M12 5v14m-6-6 6 6 6-6" />,
  "arrow-right": <path d="M5 12h14m-6-6 6 6-6 6" />,
  mail: <><rect x="3" y="5" width="18" height="14" rx="2" /><path d="m3 7 9 6 9-6" /></>,
  flame: <path d="M12 21c4 0 7-2.7 7-6.5 0-3-2-5.5-3.5-7-.3 2-1.3 3-2.5 3.5C13.5 7.5 12 5 9.5 3c.5 3-3.5 5.5-3.5 10.5C6 18.3 8.5 21 12 21Z" />,
  sparkles: <path d="M12 3v4m0 10v4M3 12h4m10 0h4M6 6l2.5 2.5m7 7L18 18M6 18l2.5-2.5m7-7L18 6" />,
  info: <><circle cx="12" cy="12" r="9" /><path d="M12 11v5m0-8h.01" /></>,
  alert: <><path d="M12 3 2 20h20L12 3Z" /><path d="M12 10v4m0 3h.01" /></>,
  refresh: <path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v4h-4" />,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
  history: <path d="M3 12a9 9 0 1 0 3-6.7M3 4v4h4m5-1v5l3 2" />,
  share: <path d="M12 4v11m-4-7 4-4 4 4M5 13v6a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-6" />,
  shield: <path d="M12 3 4 6v6c0 4.5 3.4 8 8 9 4.6-1 8-4.5 8-9V6l-8-3Z" />,
  star: <path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9L12 3Z" />,
  payout: <path d="M12 3v18m4.5-14.5C15.5 5.6 14 5 12 5c-2.5 0-4.5 1.3-4.5 3.25S9.5 11 12 11.5s4.5 1.3 4.5 3.25S14.5 19 12 19c-2 0-3.5-.6-4.5-1.5" />,
  external: <path d="M14 4h6v6m0-6-9 9M19 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1h5" />,
  volume: <path d="M4 9v6h4l5 4V5L8 9H4Zm12 0a4 4 0 0 1 0 6m2.5-9a8 8 0 0 1 0 12" />,
  mute: <path d="M4 9v6h4l5 4V5L8 9H4Zm12 1 5 5m0-5-5 5" />,
  expand: <path d="M4 9V4h5m6 0h5v5m0 6v5h-5m-6 0H4v-5" />,
  "skip-next": <path d="M5 5v14l10-7L5 5Zm13 0v14" />,
  "skip-prev": <path d="M19 5v14L9 12l10-7ZM6 5v14" />,
  list: <path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01" />,
  link: <path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1" />,
  dots: <><circle cx="5" cy="12" r="1.5" fill="currentColor" /><circle cx="12" cy="12" r="1.5" fill="currentColor" /><circle cx="19" cy="12" r="1.5" fill="currentColor" /></>,
} as const;

export type IconName = keyof typeof paths;

export function Icon({
  name,
  size = 20,
  strokeWidth = 1.8,
  ...props
}: { name: IconName; size?: number; strokeWidth?: number } & SVGProps<SVGSVGElement>) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      {paths[name]}
    </svg>
  );
}
