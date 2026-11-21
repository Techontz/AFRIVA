/**
 * Looping film-set scene for episodes whose video is not uploaded yet:
 * a camera operator films an actor under a spotlight while the clapperboard snaps.
 * Pure SVG + CSS animation (no JS), so it costs nothing to render.
 */
export function ProductionScene({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 260 150" className={className} role="img" aria-hidden>
      <style>{`
        .ps-beam{animation:ps-pulse 2.4s ease-in-out infinite}
        .ps-reel{transform-box:fill-box;transform-origin:center;animation:ps-spin 1.2s linear infinite}
        .ps-rec{animation:ps-blink 1.2s steps(1) infinite}
        .ps-arm{transform-box:view-box;transform-origin:185px 88px;animation:ps-talk 1.2s ease-in-out infinite}
        .ps-op{animation:ps-bob 2.4s ease-in-out infinite}
        .ps-clap{transform-box:view-box;transform-origin:132px 117px;animation:ps-clap 2.4s ease-in infinite}
        @keyframes ps-pulse{0%,100%{opacity:.75}50%{opacity:1}}
        @keyframes ps-spin{to{transform:rotate(360deg)}}
        @keyframes ps-blink{0%{opacity:1}50%{opacity:0}}
        @keyframes ps-talk{0%,100%{transform:rotate(0)}50%{transform:rotate(28deg)}}
        @keyframes ps-bob{0%,100%{transform:translateY(0)}50%{transform:translateY(1.5px)}}
        @keyframes ps-clap{0%{transform:rotate(0)}75%{transform:rotate(-30deg)}90%,100%{transform:rotate(0)}}
        @media (prefers-reduced-motion:reduce){.ps-beam,.ps-reel,.ps-rec,.ps-arm,.ps-op,.ps-clap{animation:none}}
      `}</style>
      <defs>
        <linearGradient id="ps-light" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".38" />
          <stop offset="1" stopColor="#fff" stopOpacity=".02" />
        </linearGradient>
      </defs>
      <line x1="8" y1="140" x2="252" y2="140" stroke="#fff" strokeOpacity=".35" strokeWidth="2" strokeLinecap="round" />

      {/* Spotlight */}
      <g className="ps-beam">
        <path d="M226 6h6l-22 134h-56z" fill="url(#ps-light)" />
        <ellipse cx="193" cy="139" rx="43" ry="5" fill="#fff" fillOpacity=".12" />
      </g>
      <rect x="218" y="0" width="22" height="10" rx="3" fill="#fff" fillOpacity=".9" />

      <g fill="#fff" fillOpacity=".9" stroke="#fff" strokeOpacity=".9" strokeWidth="3" strokeLinecap="round">
        {/* Actor */}
        <circle cx="193" cy="70" r="9" stroke="none" />
        <rect x="184" y="82" width="18" height="32" rx="8" stroke="none" />
        <path d="M189 114l-2 25M197 114l2 25M201 88l6 20" fill="none" />
        <path className="ps-arm" d="M185 88l-15 -10" fill="none" />

        {/* Camera on tripod */}
        <path d="M86 88l-16 51M86 88l16 51M86 88v51" fill="none" />
        <rect x="64" y="64" width="44" height="26" rx="5" stroke="none" />
        <path d="M108 70l16-7v28l-16-7z" stroke="none" />
        {[75, 98].map((x) => (
          <g key={x}>
            <circle cx={x} cy="50" r="11" stroke="none" />
            <g className="ps-reel" stroke="#000" strokeOpacity=".55" strokeWidth="2.4">
              <circle cx={x} cy="50" r="7.5" fill="none" stroke="none" />
              <path d={`M${x} 50v-7M${x} 50l6 3.5M${x} 50l-6 3.5`} fill="none" />
            </g>
          </g>
        ))}

        {/* Camera operator */}
        <g className="ps-op">
          <circle cx="40" cy="66" r="9" stroke="none" />
          <rect x="31" y="56" width="22" height="5" rx="2" fill="#E90204" fillOpacity="1" stroke="none" />
          <rect x="31" y="78" width="18" height="34" rx="8" stroke="none" />
          <path d="M46 86l18-10M36 112l-3 27M44 112l3 27" fill="none" />
        </g>

        {/* Clapperboard */}
        <rect x="132" y="118" width="30" height="21" rx="2" stroke="none" />
        <path d="M136 127h22M136 132h16" stroke="#000" strokeOpacity=".5" strokeWidth="1.5" />
        <g className="ps-clap">
          <rect x="132" y="111" width="30" height="6" rx="1.5" stroke="none" />
          <path d="M136 117l4-6h4l-4 6zM144 117l4-6h4l-4 6zM152 117l4-6h4l-4 6z" fill="#E90204" fillOpacity="1" stroke="none" />
        </g>
      </g>
      <circle className="ps-rec" cx="72" cy="71" r="3" fill="#E90204" />
    </svg>
  );
}
