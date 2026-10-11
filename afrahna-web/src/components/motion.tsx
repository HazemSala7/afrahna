'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * The whole motion system, in one file and no dependencies.
 *
 * A library like framer-motion would cost 50 KB before it animated anything —
 * on a site whose entire JavaScript budget is under 100 KB. Everything here is
 * CSS keyframes triggered by one IntersectionObserver, so the browser runs the
 * animation on the compositor and JavaScript's only job is to add a class and
 * get out of the way. Each observer disconnects the moment it has fired.
 */

/** True when the reader has asked the system for less movement. */
function reduced() {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

/**
 * Fires once, the first time the element is on screen.
 *
 * Shared by everything below so the page never has more observers than it has
 * animated things, and never keeps one alive after it has done its job.
 */
function useInView<T extends HTMLElement>(threshold = 0.08) {
  const ref = useRef<T>(null);
  const [seen, setSeen] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const io = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        setSeen(true);
        io.disconnect();
      },
      // Fires a little before the element is fully in view, so the animation
      // is already under way by the time the reader's eye arrives.
      { rootMargin: '0px 0px -8% 0px', threshold },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [threshold]);

  return [ref, seen] as const;
}

/* ------------------------------------------------------------------ reveal */

type RevealKind = 'rise' | 'zoom' | 'fade' | 'right' | 'left' | 'flip' | 'blur' | 'pop';

const KIND: Record<RevealKind, string> = {
  rise: 'reveal',
  zoom: 'reveal reveal-zoom',
  fade: 'reveal reveal-fade',
  right: 'reveal reveal-right',
  left: 'reveal reveal-left',
  flip: 'reveal reveal-flip',
  blur: 'reveal reveal-blur',
  pop: 'reveal reveal-pop',
};

/** Eases its child in when it first scrolls into view, once. */
export function Reveal({
  children,
  delay = 0,
  kind = 'rise',
  className = '',
  as: Tag = 'div',
}: {
  children: React.ReactNode;
  /** Milliseconds. Stagger a row by passing 60, 120, 180… */
  delay?: number;
  kind?: RevealKind;
  className?: string;
  /** `div` wrecks a `<dl>` or a `<ul>`; pass the tag the parent expects. */
  as?: 'div' | 'li' | 'span' | 'section';
}) {
  const [ref, seen] = useInView<HTMLDivElement>();

  return (
    <Tag
      ref={ref as React.Ref<never>}
      className={`${KIND[kind]} ${seen ? 'in' : ''} ${className}`}
      style={seen && delay ? { animationDelay: `${delay}ms` } : undefined}
    >
      {children}
    </Tag>
  );
}

/**
 * Brings its children in one after another.
 *
 * The alternative — a `<Reveal delay={i * 90}>` around every card — meant an
 * observer per card and a delay computed in the markup. This is one observer
 * and one class; the delays are `nth-child` rules in the stylesheet.
 */
export function Stagger({
  children,
  className = '',
  as: Tag = 'div',
}: {
  children: React.ReactNode;
  className?: string;
  as?: 'div' | 'ul' | 'dl';
}) {
  const [ref, seen] = useInView<HTMLDivElement>();

  return (
    <Tag
      ref={ref as React.Ref<never>}
      className={`stagger ${seen ? 'in' : ''} ${className}`}
    >
      {children}
    </Tag>
  );
}

/* -------------------------------------------------------------- typography */

/**
 * Animates a heading in one character at a time.
 *
 * Arabic is cursive: splitting a word into per-character `<span>`s breaks the
 * joins between letters and renders ا ل س ل ا م instead of السلام. So the split
 * is per **word**, which keeps every shape intact and still reads as writing
 * appearing rather than text switching on.
 */
export function SplitText({
  text,
  className = '',
  step = 85,
  as: Tag = 'span',
}: {
  text: string;
  className?: string;
  /** Milliseconds between one word and the next. */
  step?: number;
  as?: 'span' | 'h1' | 'h2' | 'p';
}) {
  const [ref, seen] = useInView<HTMLElement>(0.2);
  const words = text.split(' ');

  return (
    <Tag ref={ref as React.Ref<never>} className={className}>
      {words.map((w, i) => (
        <span
          key={`${w}-${i}`}
          // `inline-block` is what makes the transform possible at all; an
          // inline span cannot be moved.
          className="inline-block whitespace-pre"
          style={{
            opacity: seen ? undefined : 0,
            animation: seen
              ? `letter-in 0.7s cubic-bezier(0.34,1.56,0.64,1) ${i * step}ms both`
              : undefined,
          }}
        >
          {w}
          {i < words.length - 1 ? ' ' : ''}
        </span>
      ))}
    </Tag>
  );
}

/**
 * Counts up to a number the first time it is seen.
 *
 * Reads as "this is a living directory" rather than "here is a figure". The
 * duration is fixed rather than proportional so a big number and a small one
 * finish together in a row of statistics.
 */
export function CountUp({
  to,
  duration = 1600,
  className = '',
}: {
  to: number;
  duration?: number;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);
  const [n, setN] = useState(0);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    if (reduced()) {
      setN(to);
      return;
    }

    let raf = 0;
    const io = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        io.disconnect();
        const start = performance.now();
        const tick = (now: number) => {
          const t = Math.min(1, (now - start) / duration);
          // Ease-out cubic: fast at first, settling on the real figure.
          setN(Math.round(to * (1 - (1 - t) ** 3)));
          if (t < 1) raf = requestAnimationFrame(tick);
        };
        raf = requestAnimationFrame(tick);
      },
      { threshold: 0.3 },
    );
    io.observe(el);
    return () => {
      io.disconnect();
      cancelAnimationFrame(raf);
    };
  }, [to, duration]);

  return (
    <span ref={ref} className={className}>
      {n.toLocaleString('ar-EG')}
    </span>
  );
}

/* ------------------------------------------------------------------ scroll */

/**
 * Moves its child a little slower than the page scrolls.
 *
 * Bounded to a few dozen pixels: parallax reads as depth at that scale and as
 * a broken layout past it.
 */
export function Parallax({
  children,
  strength = 26,
  className = '',
}: {
  children: React.ReactNode;
  strength?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (reduced()) return;

    let raf = 0;
    let visible = false;

    const apply = () => {
      raf = 0;
      const rect = el.getBoundingClientRect();
      // -1 when the element is below the fold, +1 when it is above it.
      const progress =
        (rect.top + rect.height / 2 - window.innerHeight / 2) /
        (window.innerHeight / 2 + rect.height / 2);
      el.style.transform = `translate3d(0, ${(-progress * strength).toFixed(1)}px, 0)`;
    };

    const onScroll = () => {
      if (!visible || raf) return;
      raf = requestAnimationFrame(apply);
    };

    // Only listen while the element is actually on screen.
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
      if (visible) apply();
    });
    io.observe(el);

    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      io.disconnect();
      window.removeEventListener('scroll', onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, [strength]);

  return (
    <div ref={ref} className={className} style={{ willChange: 'transform' }}>
      {children}
    </div>
  );
}

/* ------------------------------------------------------------------- hover */

/**
 * Pulls a button gently towards the pointer.
 *
 * The effect that makes a call-to-action feel like an object rather than a
 * rectangle. Bounded to a handful of pixels and disabled on touch, where there
 * is no pointer to be pulled towards and the transform would only fight the
 * scroll.
 */
export function Magnetic({
  children,
  strength = 0.28,
  className = '',
}: {
  children: React.ReactNode;
  /** Fraction of the distance from the centre. Past ~0.4 it looks broken. */
  strength?: number;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);
  const [enabled, setEnabled] = useState(false);

  useEffect(() => {
    setEnabled(
      window.matchMedia('(hover: hover) and (pointer: fine)').matches && !reduced(),
    );
  }, []);

  const onMove = useCallback(
    (e: React.MouseEvent) => {
      const el = ref.current;
      if (!el) return;
      const r = el.getBoundingClientRect();
      const x = (e.clientX - (r.left + r.width / 2)) * strength;
      const y = (e.clientY - (r.top + r.height / 2)) * strength;
      el.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
      el.style.transition = 'transform 120ms ease-out';
    },
    [strength],
  );

  const onLeave = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    el.style.transform = 'translate3d(0,0,0)';
    el.style.transition = 'transform 620ms cubic-bezier(0.34,1.56,0.64,1)';
  }, []);

  if (!enabled) return <span className={`inline-block ${className}`}>{children}</span>;

  return (
    <span
      className={`inline-block ${className}`}
      onMouseMove={onMove}
      onMouseLeave={onLeave}
    >
      <span ref={ref} className="inline-block will-change-transform">
        {children}
      </span>
    </span>
  );
}
