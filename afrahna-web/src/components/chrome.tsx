'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * The page furniture that reacts to the pointer and the scroll.
 *
 * Every listener here is passive and writes exactly one transform or custom
 * property inside a `requestAnimationFrame`. Nothing measures layout on
 * scroll, which is the usual way a "smooth" site turns janky the moment it is
 * on a real phone.
 */

function reduced() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/**
 * How far down the page the reader is, 0–1.
 *
 * One listener shared by the two pieces of chrome that need it, rather than
 * one each.
 */
function useScrollProgress() {
  const [p, setP] = useState(0);

  useEffect(() => {
    let raf = 0;
    const measure = () => {
      raf = 0;
      const doc = document.documentElement;
      const max = doc.scrollHeight - doc.clientHeight;
      setP(max > 0 ? Math.min(1, doc.scrollTop / max) : 0);
    };
    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(measure);
    };
    measure();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);

  return p;
}

/** A gold hairline across the top showing how far down the page you are. */
export function ScrollProgress() {
  const p = useScrollProgress();

  return (
    <div className="pointer-events-none fixed inset-x-0 top-0 z-[70] h-[3px]" aria-hidden>
      <div
        className="h-full origin-right bg-gradient-to-l from-brand-accent via-brand to-brand-dark"
        style={{ transform: `scaleX(${p})` }}
      >
        {/* A bead of light riding the leading edge of the bar. */}
        <span className="absolute left-0 top-1/2 h-2 w-2 -translate-y-1/2 rounded-full bg-brand-accent shadow-[0_0_10px_3px_rgba(212,163,115,0.8)]" />
      </div>
    </div>
  );
}

/**
 * Appears once the reader is a screen down, and takes them back up.
 *
 * The ring around it is the same scroll progress as the bar at the top — at
 * the bottom of a long page the top bar is the one thing the reader is not
 * looking at, so the figure is repeated where their eye already is.
 */
export function BackToTop() {
  const p = useScrollProgress();
  const [show, setShow] = useState(false);

  useEffect(() => {
    const onScroll = () => setShow(window.scrollY > window.innerHeight);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const R = 21;
  const C = 2 * Math.PI * R;

  return (
    <button
      type="button"
      onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
      aria-label="العودة إلى الأعلى"
      className={`group fixed bottom-24 left-5 z-30 grid h-12 w-12 place-items-center md:bottom-6 md:left-6
                  rounded-full bg-gradient-to-br from-brand-accent to-brand-dark
                  text-white shadow-lift transition-all duration-500
                  ${
                    show
                      ? 'translate-y-0 scale-100 opacity-100'
                      : 'pointer-events-none translate-y-4 scale-90 opacity-0'
                  }`}
    >
      <svg
        viewBox="0 0 48 48"
        className="absolute inset-0 h-full w-full -rotate-90"
        fill="none"
        aria-hidden
      >
        <circle cx="24" cy="24" r={R} stroke="rgba(255,255,255,0.25)" strokeWidth="2.5" />
        <circle
          cx="24"
          cy="24"
          r={R}
          stroke="#FFF7EC"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeDasharray={C}
          strokeDashoffset={C * (1 - p)}
          style={{ transition: 'stroke-dashoffset 120ms linear' }}
        />
      </svg>
      <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        className="relative transition-transform duration-300 group-hover:-translate-y-0.5"
        aria-hidden
      >
        <path
          d="M12 19V5M5 12l7-7 7 7"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </button>
  );
}

/**
 * A warm follow-spot under the pointer.
 *
 * The whole effect is one fixed div whose position is written straight to the
 * DOM node — never through React state, which would re-render the tree on
 * every mouse move.
 *
 * Deliberately *not* `mix-blend-mode: multiply`, which is what this wanted to
 * be: a blended fixed layer has to composite against everything beneath it, so
 * the browser gives up the cheap GPU layer and repaints a screen's worth of
 * page on every mouse move. A low-alpha gold gradient over cream paper lands
 * in the same place visually and stays on its own layer.
 *
 * Desktop only: on a touch screen there is no pointer to follow.
 */
export function CursorGlow() {
  const ref = useRef<HTMLDivElement>(null);
  const [on, setOn] = useState(false);

  useEffect(() => {
    if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;
    if (reduced()) return;
    setOn(true);

    let raf = 0;
    let x = 0;
    let y = 0;

    const paint = () => {
      raf = 0;
      const el = ref.current;
      if (el) el.style.transform = `translate3d(${x - 180}px, ${y - 180}px, 0)`;
    };

    const onMove = (e: MouseEvent) => {
      x = e.clientX;
      y = e.clientY;
      const el = ref.current;
      if (el && el.style.opacity !== '1') el.style.opacity = '1';
      if (!raf) raf = requestAnimationFrame(paint);
    };

    window.addEventListener('mousemove', onMove, { passive: true });
    return () => {
      window.removeEventListener('mousemove', onMove);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);

  if (!on) return null;

  return (
    <div
      ref={ref}
      aria-hidden
      className="pointer-events-none fixed left-0 top-0 z-[5] h-[360px] w-[360px] rounded-full opacity-0"
      style={{
        background:
          'radial-gradient(circle, rgba(212,163,115,0.20) 0%, rgba(217,133,123,0.08) 42%, rgba(212,163,115,0) 70%)',
        willChange: 'transform',
        transition: 'opacity 600ms ease',
      }}
    />
  );
}

/**
 * Tilts a card towards the pointer, with a sheet of light that moves across it
 * as it turns.
 *
 * Desktop only, and deliberately shallow: past about eight degrees it stops
 * reading as a card catching the light and starts reading as a bug. Disabled
 * for coarse pointers, where there is no hover to respond to and the transform
 * would only fight the scroll.
 */
export function Tilt({
  children,
  max = 7,
  glare = true,
  className = '',
}: {
  children: React.ReactNode;
  max?: number;
  /** The moving highlight. Worth switching off over busy photography. */
  glare?: boolean;
  className?: string;
}) {
  const inner = useRef<HTMLDivElement>(null);
  const sheen = useRef<HTMLSpanElement>(null);
  const [enabled, setEnabled] = useState(false);

  useEffect(() => {
    setEnabled(
      window.matchMedia('(hover: hover) and (pointer: fine)').matches && !reduced(),
    );
  }, []);

  if (!enabled) return <div className={className}>{children}</div>;

  return (
    <div
      className={className}
      style={{ perspective: '1100px' }}
      onMouseMove={(e) => {
        const r = e.currentTarget.getBoundingClientRect();
        const x = (e.clientX - r.left) / r.width - 0.5;
        const y = (e.clientY - r.top) / r.height - 0.5;
        const el = inner.current;
        if (el) {
          el.style.transform = `rotateY(${x * max}deg) rotateX(${-y * max}deg) scale(1.015)`;
          el.style.transition = 'transform 120ms ease-out';
        }
        const g = sheen.current;
        if (g) {
          // The highlight sits opposite the tilt, the way a reflection does.
          g.style.opacity = '1';
          g.style.background = `radial-gradient(circle at ${(0.5 - x) * 100}% ${
            (0.5 - y) * 100
          }%, rgba(255,255,255,0.35), rgba(255,255,255,0) 55%)`;
        }
      }}
      onMouseLeave={() => {
        const el = inner.current;
        if (el) {
          el.style.transform = 'rotateY(0deg) rotateX(0deg) scale(1)';
          el.style.transition = 'transform 650ms cubic-bezier(0.16,1,0.3,1)';
        }
        const g = sheen.current;
        if (g) g.style.opacity = '0';
      }}
    >
      <div ref={inner} className="relative preserve-3d">
        {children}
        {glare && (
          <span
            ref={sheen}
            aria-hidden
            className="pointer-events-none absolute inset-0 z-10 rounded-[1.7rem] opacity-0"
            style={{ transition: 'opacity 350ms ease' }}
          />
        )}
      </div>
    </div>
  );
}
