"use client";

import Image from "next/image";
import Link from "next/link";
import { Icon } from "@/components/ui/Icon";
import { useT } from "@/i18n/client";
import { fmt, plural } from "@/i18n/format";
import { cn } from "@/lib/format";
import type { Drama } from "@/lib/types";
import { dramaGenres, genreName } from "../PosterCard";
import {
  Dot,
  HeroArrow,
  HeroBadge,
  HeroDots,
  ProgressFill,
  detailsHref,
  playHref,
  useHeroCarousel,
  type HeroProps,
} from "./shared";
import { BLEED, HERO_HEIGHT, PAD } from "./layout";

/** Bleeds out of .site-container so the banner spans the page width (mirrors its padding). */

/**
 * Variant 1, "Cinematic": a full-width banner. Blurred poster art fills the background, the copy
 * (badge, title, episodes, genres, synopsis, Play / More info) sits on the left and the sharp poster
 * stands on the right. A strip of small posters doubles as the slide picker and progress.
 */
export function HeroCinematic({ dramas, labels }: HeroProps) {
  const c = useHeroCarousel(dramas.length);
  const { episodes: eps, categories: genres } = useT().site.card;

  return (
    <section
      aria-roledescription="carousel"
      aria-label={labels.label}
      className={cn(BLEED, HERO_HEIGHT, "relative overflow-hidden bg-bg")}
      {...c.rootProps}
    >
      {dramas.map((d, i) => {
        const active = i === c.index;
        return (
          <div
            key={d.id}
            role="group"
            aria-roledescription="slide"
            aria-label={fmt(labels.slide, { n: i + 1, total: dramas.length })}
            aria-hidden={!active}
            inert={!active}
            className={cn(
              "absolute inset-0 transition-opacity duration-[900ms] ease-brand",
              active ? "z-10 opacity-100" : "z-0 opacity-0",
            )}
          >
            {/* Background: the poster, blown up and blurred, slowly drifting. */}
            <div className="absolute inset-0 overflow-hidden" aria-hidden>
              {d.poster_url && (
                <Image
                  src={d.poster_url}
                  alt=""
                  fill
                  sizes="100vw"
                  loading={i === 0 ? "eager" : "lazy"}
                  className={cn(
                    "object-cover blur-3xl saturate-150 transition-transform duration-[6000ms] ease-out [:root[data-theme=light]_&]:opacity-50",
                    active ? "scale-125" : "scale-110",
                  )}
                />
              )}
              {/* Fades: into the page on the left (copy side) and at the bottom. */}
              <div className="absolute inset-0 bg-gradient-to-t from-bg via-bg/40 to-bg/10 lg:bg-gradient-to-r lg:from-bg lg:via-bg/80 lg:to-bg/5" />
              <div className="absolute inset-x-0 bottom-0 h-40 bg-gradient-to-t from-bg to-transparent" />
            </div>

            <div className={cn(PAD, "relative mx-auto flex h-full max-w-[1680px] flex-col items-center pb-14 pt-[calc(var(--header-h)+0.25rem)] lg:flex-row lg:items-center lg:gap-12 lg:pb-0 lg:pt-(--header-h)")}>
              {/* Copy */}
              <div
                className={cn(
                  "order-2 flex w-full flex-col items-center text-center transition-all ease-brand lg:order-1 lg:max-w-[560px] lg:flex-1 lg:items-start lg:pb-28 lg:text-left xl:max-w-[640px]",
                  // The outgoing copy disappears quickly so two titles never overlap mid-transition.
                  active ? "translate-y-0 opacity-100 delay-300 duration-700" : "translate-y-6 opacity-0 delay-0 duration-150",
                )}
              >
                <div className="mt-5 flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-[13px] font-medium text-text-muted lg:mt-0 lg:justify-start lg:text-sm">
                  <HeroBadge badge={d.badge} />
                  <span>{plural(d.total_episodes, eps)}</span>
                  {dramaGenres(d, 3).map((g) => (
                    <span key={g} className="flex items-center gap-3">
                      <Dot />
                      {genreName(g, genres)}
                    </span>
                  ))}
                </div>
                <h2 className="mt-3 line-clamp-2 text-[28px] font-extrabold leading-[1.08] tracking-tight text-text sm:text-4xl lg:mt-4 lg:text-5xl xl:text-[56px]">
                  {d.title}
                </h2>
                <p className="mt-4 hidden text-[17px] leading-relaxed text-text-muted lg:line-clamp-3">{d.synopsis}</p>
                <div className="mt-5 flex items-center gap-3 lg:mt-7">
                  <Link
                    href={playHref(d)}
                    className="inline-flex h-11 items-center gap-2 rounded-full bg-primary px-6 text-[15px] font-semibold text-white shadow-[0_10px_30px_-8px_rgba(233,2,4,0.7)] transition hover:bg-primary-hover lg:h-12 lg:px-8"
                  >
                    <Icon name="play" size={18} className="fill-current" />
                    {labels.play}
                  </Link>
                  <Link
                    href={detailsHref(d)}
                    className="inline-flex h-11 items-center gap-2 rounded-full bg-text/10 px-5 text-[15px] font-semibold text-text backdrop-blur-md transition hover:bg-text/20 lg:h-12 lg:px-7"
                  >
                    <Icon name="info" size={18} />
                    {labels.moreInfo}
                  </Link>
                </div>
              </div>

              {/* Poster */}
              <Link
                href={detailsHref(d)}
                tabIndex={-1}
                aria-hidden
                className={cn(
                  "relative order-1 aspect-[9/16] h-[290px] shrink-0 overflow-hidden rounded-[18px] shadow-[0_30px_80px_-20px_rgba(0,0,0,0.85)] transition-all duration-[900ms] ease-brand sm:h-[330px] lg:order-2 lg:ml-auto lg:mr-[6%] lg:h-[480px] xl:h-[540px]",
                  active ? "translate-x-0 scale-100 opacity-100" : "translate-x-10 scale-95 opacity-0",
                )}
              >
                {d.poster_url && (
                  <Image
                    src={d.poster_url}
                    alt={d.title}
                    fill
                    sizes="(max-width: 1024px) 200px, 320px"
                    loading={i === 0 ? "eager" : "lazy"}
                    fetchPriority={i === 0 ? "high" : undefined}
                    className="object-cover"
                  />
                )}
              </Link>
            </div>
          </div>
        );
      })}

      {/* Thumbnail strip (desktop) / dots (mobile) */}
      <div className={cn(PAD, "absolute inset-x-0 bottom-6 z-20 mx-auto max-w-[1680px] lg:bottom-10")}>
        <HeroDots count={dramas.length} index={c.index} go={c.go} paused={c.paused} autoplay={c.autoplay} next={c.next} labels={labels} className="lg:hidden" />
        {dramas.length > 1 && (
          <div className="hidden lg:block">
            <p className="mb-2.5 text-xs font-semibold uppercase tracking-[0.18em] text-text-muted">{labels.upNext}</p>
            <div className="flex items-center gap-3">
              {dramas.map((d, i) => (
                <Thumb key={d.id} drama={d} active={i === c.index} onClick={() => c.go(i)} label={fmt(labels.goTo, { n: i + 1 })}>
                  {i === c.index && <ProgressFill index={c.index} paused={c.paused} autoplay={c.autoplay} onDone={c.next} />}
                </Thumb>
              ))}
              <div className="ml-4 flex gap-2.5">
                <HeroArrow dir="left" onClick={c.previous} label={labels.previous} />
                <HeroArrow dir="right" onClick={c.next} label={labels.next} />
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  );
}

function Thumb({
  drama: d,
  active,
  onClick,
  label,
  children,
}: {
  drama: Drama;
  active: boolean;
  onClick: () => void;
  label: string;
  children?: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={`${label}: ${d.title}`}
      aria-current={active ? "true" : undefined}
      className={cn(
        "group relative w-[54px] shrink-0 transition-all duration-500 ease-brand xl:w-[62px]",
        active ? "-translate-y-1" : "opacity-60 hover:opacity-100",
      )}
    >
      <span
        className={cn(
          "relative block aspect-[9/16] overflow-hidden rounded-lg ring-2 transition",
          active ? "ring-primary" : "ring-transparent group-hover:ring-text/40",
        )}
      >
        {d.poster_url && <Image src={d.poster_url} alt="" fill sizes="62px" loading="lazy" className="object-cover" />}
      </span>
      <span className="relative mt-1.5 block h-[3px] overflow-hidden rounded-full bg-text/15">{children}</span>
    </button>
  );
}
