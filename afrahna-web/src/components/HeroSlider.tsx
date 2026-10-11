'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';

export interface Slide {
  id: number;
  image: string;
  title: string;
  subtitle?: string;
  badge?: string;
  href: string;
}

const DWELL = 7000;

/**
 * The hero banner — the app's slider, on the web, across the full width.
 *
 * Built on native scroll-snap rather than a transform track: the browser does
 * the scrolling, so it is smooth on a phone, follows the finger, respects RTL,
 * and — the part that matters — **still works with JavaScript switched off**,
 * where it degrades to a row you can swipe.
 *
 * Every slide is two layers of the same picture. Behind, a blurred copy fills
 * the whole banner; in front, the picture itself, shown *whole*. Most slides
 * today are VIP shops whose "cover" is really a square logo, and a wide banner
 * cropping a square logo to a strip through its middle is what made the old
 * panel look broken. This way a logo sits on its own colour, a wide photograph
 * fills the width, and neither needs a script to decide which it is.
 */
export default function HeroSlider({ slides }: { slides: Slide[] }) {
  const track = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [held, setHeld] = useState(false);
  const paused = useRef(false);
  const resume = useRef<ReturnType<typeof setTimeout> | null>(null);

  const goTo = useCallback(
    (i: number) => {
      const el = track.current;
      if (!el) return;
      const n = slides.length;
      const target = ((i % n) + n) % n;
      // The track is RTL, so slide k sits at a negative offset.
      el.scrollTo({ left: -target * el.clientWidth, behavior: 'smooth' });
    },
    [slides.length],
  );

  /** Any touch stops the rotation, and pushes the restart four seconds out. */
  const hold = useCallback(() => {
    paused.current = true;
    setHeld(true);
    if (resume.current) clearTimeout(resume.current);
    resume.current = setTimeout(() => {
      paused.current = false;
      setHeld(false);
    }, 4000);
  }, []);

  useEffect(() => () => {
    if (resume.current) clearTimeout(resume.current);
  }, []);

  // Autoplay. Seven seconds is long enough to read a slide and short enough
  // that the next one still feels like the banner is alive.
  useEffect(() => {
    if (slides.length < 2) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    const t = setInterval(() => {
      if (paused.current || document.hidden) return;
      const el = track.current;
      if (!el) return;
      const w = el.clientWidth || 1;
      const current = Math.round(Math.abs(el.scrollLeft) / w);
      goTo(current + 1);
    }, DWELL);
    return () => clearInterval(t);
  }, [slides.length, goTo]);

  // Which slide is showing, read from the scroll position the browser owns.
  useEffect(() => {
    const el = track.current;
    if (!el) return;
    let raf = 0;
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        const w = el.clientWidth || 1;
        setIndex(Math.round(Math.abs(el.scrollLeft) / w));
      });
    };
    el.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      el.removeEventListener('scroll', onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);

  if (slides.length === 0) return null;

  const n = slides.length;
  const two = (k: number) => k.toLocaleString('ar-EG', { minimumIntegerDigits: 2 });

  return (
    // A gold hairline frame around the banner. Static on purpose: a turning
    // conic border works on a small card and swings its corners out past the
    // edges on something this wide.
    <div className="banner-open relative rounded-[1.9rem] bg-gradient-to-br from-brand-accent via-brand-light to-brand-dark p-[3px] shadow-lift">
      <div className="relative overflow-hidden rounded-[1.75rem] bg-ink">
        <div
          ref={track}
          onPointerDown={hold}
          onMouseEnter={hold}
          className="flex h-[clamp(260px,min(34vw,62vh),620px)] snap-x snap-mandatory overflow-x-auto
                     [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          aria-roledescription="carousel"
        >
          {slides.map((s, i) => {
            const active = i === index;
            return (
              <Link
                key={s.id}
                href={s.href}
                className="group relative block h-full w-full shrink-0 snap-start overflow-hidden"
                aria-label={s.title}
                aria-roledescription="slide"
              >
                <div
                  className="absolute inset-0 bg-gradient-to-br from-brand-dark/45 via-black/10 to-brand-accent/30"
                  aria-hidden
                />

                {/* ---- the picture, filling the banner the way the app shows
                    the same slide. Cropped to fill rather than fitted whole:
                    every slide is then the same shape, and the layout stops
                    depending on what each shop happened to upload. */}
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={s.image}
                  alt={s.title}
                  width={1600}
                  height={700}
                  loading={i === 0 ? 'eager' : 'lazy'}
                  fetchPriority={i === 0 ? 'high' : 'auto'}
                  decoding="async"
                  className={`absolute inset-0 h-full w-full object-cover object-center
                              transition-transform duration-[1200ms] ease-[cubic-bezier(0.16,1,0.3,1)]
                              group-hover:scale-[1.03] ${active ? 'ken-burns' : ''}`}
                />

                {/* The wash that keeps the caption readable over any picture:
                    rising from the foot on a phone, from the right-hand edge on
                    anything wider. */}
                <div
                  className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/25 to-transparent
                             sm:bg-gradient-to-l sm:from-black/80 sm:via-black/35 sm:to-transparent"
                  aria-hidden
                />

                {/* A sheet of gold light across the banner on hover. */}
                <div
                  className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-700 group-hover:opacity-100"
                  style={{
                    background:
                      'linear-gradient(115deg, transparent 30%, rgba(255,236,209,0.18) 50%, transparent 70%)',
                  }}
                  aria-hidden
                />

                <div
                  className="absolute inset-x-0 bottom-0 p-5 pb-12 text-white
                             sm:inset-y-0 sm:left-auto sm:right-0 sm:flex sm:w-[50%] sm:flex-col
                             sm:justify-center sm:p-12 lg:p-16"
                >
                  {s.badge && (
                    <span
                      className="chip w-fit !border-white/30 !bg-white/20 !text-white backdrop-blur sm:!px-4 sm:!py-1.5 sm:!text-sm"
                      style={
                        active
                          ? { animation: 'pop-in 0.6s cubic-bezier(0.34,1.56,0.64,1) 0.25s both' }
                          : undefined
                      }
                    >
                      {s.badge}
                    </span>
                  )}

                  {/* A paragraph rather than a heading: twelve shop names are
                      not twelve sections of the page. */}
                  <p
                    className="mt-3 text-2xl font-black leading-tight drop-shadow sm:mt-5 sm:text-4xl lg:text-6xl"
                    style={
                      active
                        ? { animation: 'in-right 0.8s cubic-bezier(0.16,1,0.3,1) 0.1s both' }
                        : undefined
                    }
                  >
                    {s.title}
                  </p>

                  {s.subtitle && (
                    <p
                      className="mt-1 text-sm text-white/85 sm:mt-3 sm:text-xl"
                      style={
                        active
                          ? { animation: 'in-right 0.8s cubic-bezier(0.16,1,0.3,1) 0.22s both' }
                          : undefined
                      }
                    >
                      {s.subtitle}
                    </p>
                  )}

                  {/* Says what pressing the banner does. A span, not a link:
                      the whole slide is already the link. */}
                  <span
                    className="mt-7 hidden w-fit items-center gap-2 rounded-full bg-white px-6 py-3 text-sm
                               font-black text-brand-dark shadow-lift transition-all duration-500
                               ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:gap-4 group-hover:px-7 sm:inline-flex"
                    style={
                      active
                        ? { animation: 'rise 0.8s cubic-bezier(0.16,1,0.3,1) 0.36s both' }
                        : undefined
                    }
                  >
                    شوف التفاصيل
                    <span aria-hidden>←</span>
                  </span>
                </div>
              </Link>
            );
          })}
        </div>

        {n > 1 && (
          <>
            <Arrow dir="next" onClick={() => { hold(); goTo(index + 1); }} />
            <Arrow dir="prev" onClick={() => { hold(); goTo(index - 1); }} />

            {/* Where you are in the run, in the corner the caption does not use. */}
            <span
              className="pointer-events-none absolute bottom-5 left-6 hidden font-black text-white/90
                         drop-shadow sm:block"
              aria-hidden
            >
              <span className="text-2xl">{two(Math.min(index + 1, n))}</span>
              <span className="mx-1.5 text-sm text-white/60">/</span>
              <span className="text-sm text-white/60">{two(n)}</span>
            </span>

            {/* How long this slide has left. Keyed on the index so it restarts
                with each slide, and frozen — not reset — while the reader is
                holding the banner still. */}
            <div className="pointer-events-none absolute inset-x-0 bottom-0 h-1 bg-white/15">
              <div
                key={index}
                className="h-full origin-right bg-gradient-to-l from-brand-light via-white to-brand-accent"
                style={{
                  animation: `timer-bar ${DWELL}ms linear both`,
                  animationPlayState: held ? 'paused' : 'running',
                }}
                aria-hidden
              />
            </div>

            {/* Ten dots at most: a full row for thirty slides is an unreadable
                line, and the last dot simply stays lit past the tenth. */}
            <div className="absolute inset-x-0 bottom-4 flex justify-center gap-2">
              {slides.slice(0, 10).map((_, i) => {
                const active = i === Math.min(index, Math.min(n, 10) - 1);
                return (
                  <button
                    key={i}
                    type="button"
                    onClick={() => { hold(); goTo(i); }}
                    aria-label={`الشريحة ${i + 1}`}
                    aria-current={active ? 'true' : undefined}
                    className={`h-2 rounded-full transition-all duration-500 ${
                      active
                        ? 'w-8 bg-white shadow-[0_0_12px_2px_rgba(255,255,255,0.6)]'
                        : 'w-2 bg-white/50 hover:w-4 hover:bg-white/85'
                    }`}
                  />
                );
              })}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/**
 * One of the two arrows.
 *
 * `next` is on the left and `prev` on the right: the track is RTL, so forward
 * is towards the left of the screen.
 */
function Arrow({ dir, onClick }: { dir: 'next' | 'prev'; onClick: () => void }) {
  const next = dir === 'next';
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={next ? 'التالي' : 'السابق'}
      // Hidden on a phone: the track is swipeable there, and the two buttons
      // sat on top of the slide's own badge and caption.
      className={`group absolute top-1/2 hidden h-10 w-10 -translate-y-1/2 place-items-center overflow-hidden
                  rounded-full border border-white/30 bg-white/20 text-white shadow-card backdrop-blur-md
                  transition-all duration-300 hover:scale-110 sm:grid sm:h-14 sm:w-14
                  ${next ? 'left-3 sm:left-5' : 'right-3 sm:right-5'}`}
    >
      {/* The gold floods the button from the edge it points towards. */}
      <span
        className={`absolute inset-0 scale-0 bg-gradient-to-br from-brand-accent to-brand-dark
                    transition-transform duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]
                    group-hover:scale-100 ${next ? 'origin-left' : 'origin-right'}`}
        aria-hidden
      />
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" className="relative" aria-hidden>
        <path
          d={next ? 'M15 6l-6 6 6 6' : 'M9 6l6 6-6 6'}
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </button>
  );
}
