import Link from 'next/link';

/**
 * The small shared pieces. Server components, all of them: none needs state,
 * so none of this reaches the browser as JavaScript. The movement in here is
 * hover and CSS animation only.
 */

export function SectionHeader({
  title,
  emoji,
  href,
  kicker,
  seeAll = 'عرض الكل',
}: {
  title: string;
  emoji?: string;
  href?: string;
  /** A quiet line above the heading — sets the section up in three words. */
  kicker?: string;
  seeAll?: string;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-x-4 gap-y-3">
      <div>
        {kicker && (
          <p className="mb-1.5 flex items-center gap-2 text-xs font-black uppercase tracking-[0.2em] text-brand">
            {/* A gold tick before the kicker, pulsing very slightly, so the
                line reads as a label rather than as stray small text. */}
            <span className="inline-flex h-1.5 w-1.5 shrink-0 rounded-full bg-brand-accent twinkle" aria-hidden />
            {kicker}
          </p>
        )}
        <h2 className="rule flex items-center gap-2 text-xl font-black text-ink sm:text-3xl">
          {emoji && (
            // The emoji leans in when the heading's section is hovered, which
            // is a small thing that makes a page feel answerable.
            <span className="inline-block transition-transform duration-500 hover:scale-125 hover:-rotate-12" aria-hidden>
              {emoji}
            </span>
          )}
          {title}
        </h2>
      </div>
      {href && (
        <Link
          href={href}
          className="group relative shrink-0 overflow-hidden rounded-full border border-brand-light
                     bg-white/70 px-4 py-2 text-sm font-bold text-brand-dark backdrop-blur-sm
                     transition-all duration-300 hover:-translate-y-0.5 hover:border-brand
                     hover:shadow-card"
        >
          {/* The gold sweeps in from the start edge and the label turns white
              on top of it. */}
          <span
            className="absolute inset-0 origin-right scale-x-0 bg-gradient-to-l from-brand-accent
                       to-brand-dark transition-transform duration-500
                       ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:scale-x-100"
            aria-hidden
          />
          <span className="relative transition-colors duration-300 group-hover:text-white">
            {seeAll}
            <span className="inline-block transition-transform duration-300 group-hover:-translate-x-1">
              {' '}←
            </span>
          </span>
        </Link>
      )}
    </div>
  );
}

/**
 * Every picture on the site goes through here.
 *
 * Explicit dimensions and a fixed aspect box mean the layout never jumps when
 * an image lands — the single biggest source of the "cheap site" feeling, and
 * the thing search engines measure as CLS. `loading="lazy"` on everything but
 * the hero keeps the first screen to a handful of requests.
 *
 * The box is a shimmering placeholder until the picture covers it, so a slow
 * connection sees something alive rather than a grey rectangle.
 */
export function Img({
  src,
  alt,
  className = '',
  eager = false,
  ratio = 'aspect-[4/3]',
}: {
  src?: string | null;
  alt: string;
  className?: string;
  eager?: boolean;
  ratio?: string;
}) {
  return (
    <div className={`skeleton relative overflow-hidden ${ratio} ${className}`}>
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={src}
          alt={alt}
          loading={eager ? 'eager' : 'lazy'}
          decoding="async"
          fetchPriority={eager ? 'high' : 'auto'}
          className="zoomable relative h-full w-full object-cover"
        />
      ) : (
        <div className="relative flex h-full w-full items-center justify-center text-brand/40">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" aria-hidden>
            <rect x="3" y="5" width="18" height="14" rx="3" stroke="currentColor" strokeWidth="1.6" />
            <circle cx="8.5" cy="10" r="1.6" fill="currentColor" />
            <path d="M4 17l5-4 4 3 3-2 4 3" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
          </svg>
        </div>
      )}
    </div>
  );
}

export function Stars({ value, count }: { value: string; count?: number | null }) {
  return (
    <span className="inline-flex items-center gap-1 text-xs font-bold text-ink">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="#E8B33D" className="twinkle" aria-hidden>
        <path d="M12 2l2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17l-5.9 3.2 1.2-6.6L2.5 9l6.6-.9L12 2z" />
      </svg>
      {value}
      {typeof count === 'number' && count > 0 && (
        <span className="text-ink-muted">({count.toLocaleString('ar-EG')})</span>
      )}
    </span>
  );
}

export function Badge({
  children,
  tone = 'brand',
}: {
  children: React.ReactNode;
  tone?: 'brand' | 'sale' | 'verified';
}) {
  const tones = {
    brand:
      'bg-gradient-to-br from-brand-accent to-brand-dark text-white shadow-[0_4px_12px_rgba(184,131,90,0.4)]',
    sale: 'bg-gradient-to-br from-[#E0654A] to-sale text-white shadow-[0_4px_12px_rgba(193,69,43,0.35)]',
    verified:
      'bg-gradient-to-br from-emerald-500 to-emerald-700 text-white shadow-[0_4px_12px_rgba(16,122,87,0.35)]',
  } as const;
  return (
    <span
      className={`relative inline-flex items-center gap-1 overflow-hidden rounded-full px-2.5 py-1
                  text-[11px] font-black backdrop-blur-sm transition-transform duration-300
                  group-hover:scale-105 ${tones[tone]}`}
    >
      {/* A slow band of light across the badge, so a VIP mark glints. */}
      <span
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'linear-gradient(90deg, transparent, rgba(255,255,255,0.45), transparent)',
          animation: 'sheen 4.5s ease-in-out infinite',
        }}
        aria-hidden
      />
      <span className="relative">{children}</span>
    </span>
  );
}

/** Shown where a list came back empty — a dead end explained, not a blank. */
export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="card grid place-items-center gap-2 px-6 py-14 text-center">
      <div className="float text-3xl" aria-hidden>🕊️</div>
      <p className="font-black text-ink">{title}</p>
      {hint && <p className="max-w-sm text-sm text-ink-muted">{hint}</p>}
    </div>
  );
}
