/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';

import { excerpt, name, price, rating, vendorHref } from '@/lib/format';
import type { Vendor } from '@/lib/types';

import { Bokeh, Flourish, Garland, Sparkles, WaveDivider } from './decor';
import { Magnetic, Reveal, Stagger } from './motion';
import { Badge } from './ui';

/**
 * The featured shops — the showcase directly under the hero.
 *
 * These are the shops that pay to be seen, so they get the one dark room on a
 * cream site: an evening band the colour of a candlelit hall, gold at every
 * edge, lights hung across the top. Against it the cards are the brightest
 * thing on the screen, which is the whole point.
 *
 * "Clearer" was the other half of the brief, and the old card failed it in
 * three specific ways this one fixes:
 *  - **Pictures were cropped.** Half these shops' covers are square logos, and
 *    a 16:10 crop cut them to a strip. Every picture is now shown whole, over a
 *    blurred copy of itself.
 *  - **Cards were ragged.** Some had a description and some did not, so rows
 *    never lined up. Every card now has the same parts at the same heights.
 *  - **The facts were faint.** Category, city, rating and starting price now
 *    each have their own mark instead of one grey line.
 */
export default function FeaturedVendors({ vendors }: { vendors: Vendor[] }) {
  if (vendors.length === 0) return null;

  // Twelve when there are twelve — three rows of four, or two rows of six on
  // a wide screen — otherwise eight in two rows of four. Every row stays full.
  const shown = vendors.length >= 12 ? vendors.slice(0, 12) : vendors.slice(0, 8);

  return (
    <section aria-labelledby="featured-title" className="relative mt-10">
      {/* A curved edge into the band and out of it, instead of a hard line. */}
      <div className="text-[#2B1B10]">
        <WaveDivider />
      </div>

      <div className="grain relative overflow-hidden bg-[#2B1B10] pb-16 pt-14 sm:pb-20 sm:pt-16">
        {/* ---- the room ---- */}
        <div
          className="pointer-events-none absolute -top-48 left-1/2 h-[560px] w-[960px] max-w-[140%] -translate-x-1/2 rounded-full bg-brand-accent/20 blur-[120px]"
          aria-hidden
        />
        <div
          className="pointer-events-none absolute -bottom-40 -left-24 h-96 w-96 rounded-full bg-sale/15 blur-[110px]"
          aria-hidden
        />
        <Garland bulbs={15} />
        <Bokeh count={14} rise="-1000px" />
        <Sparkles count={14} />

        <div className="container-site relative">
          {/* ---- the heading ---- */}
          <header className="mx-auto max-w-2xl text-center">
            <Reveal kind="pop">
              <span className="relative mx-auto grid h-20 w-20 place-items-center">
                <svg
                  viewBox="0 0 80 80"
                  className="spin-slow absolute inset-0 h-full w-full text-brand-accent/70"
                  fill="none"
                  stroke="currentColor"
                  aria-hidden
                >
                  <circle cx="40" cy="40" r="37" strokeWidth="1.2" strokeDasharray="4 6" />
                </svg>
                <span className="float grid h-14 w-14 place-items-center rounded-full bg-gradient-to-br from-[#F3D9B1] via-brand-accent to-brand-dark shadow-[0_0_40px_rgba(212,163,115,0.55)]">
                  <Crown className="h-7 w-7 text-[#2B1B10]" />
                </span>
              </span>
            </Reveal>

            <Reveal delay={80}>
              <p className="mt-5 flex items-center justify-center gap-3 text-sm font-black text-brand-accent">
                <span className="h-px w-12 bg-gradient-to-r from-brand-accent to-transparent" aria-hidden />
                اختيار أفراحنا
                <span className="h-px w-12 bg-gradient-to-l from-brand-accent to-transparent" aria-hidden />
              </p>
            </Reveal>

            <Reveal delay={140}>
              <h2 id="featured-title" className="mt-3 text-3xl font-black leading-tight sm:text-5xl">
                <span className="foil-gold">الشركات المميّزة</span>
              </h2>
            </Reveal>

            <Reveal delay={200}>
              <p className="mt-4 text-sm leading-relaxed text-cream/70 sm:text-base">
                محلات مختارة بعناية من فريق أفراحنا — موثوقة، بتقييمات عالية،
                وشغلها بيحكي عنها.
              </p>
            </Reveal>

            <Reveal kind="fade" delay={240}>
              <Flourish className="mx-auto mt-6 w-40 !text-brand-accent" />
            </Reveal>
          </header>

          {/* ---- the cards ----
              A swipeable row on a phone, where eight stacked cards would be a
              very long scroll past one section; a grid from a tablet up. */}
          <Stagger
            className={`-mx-4 mt-10 flex snap-x snap-mandatory gap-4 overflow-x-auto px-4 py-4
                       [scrollbar-width:none] [&::-webkit-scrollbar]:hidden
                       sm:mx-0 sm:mt-12 sm:grid sm:grid-cols-2 sm:gap-6 sm:overflow-visible sm:px-0
                       lg:grid-cols-4 ${shown.length === 12 ? '2xl:grid-cols-6' : ''}`}
          >
            {shown.map((v, i) => (
              <FeaturedCard key={v.id} vendor={v} eager={i < 4} />
            ))}
          </Stagger>

          <Reveal delay={120} className="mt-10 text-center sm:mt-12">
            <Magnetic>
              <Link
                href="/vendors"
                className="btn border border-brand-accent/60 bg-white/5 !px-8 !py-3.5 text-[#F3D9B1] backdrop-blur
                           hover:border-brand-accent hover:bg-brand-accent hover:text-[#2B1B10]"
              >
                شوف كل المحلات
                <span aria-hidden>←</span>
              </Link>
            </Magnetic>
          </Reveal>
        </div>
      </div>

      <div className="-mt-px">
        <div className="text-[#2B1B10]">
          <WaveDivider flip />
        </div>
      </div>
    </section>
  );
}

/* ----------------------------------------------------------------- the card */

function FeaturedCard({ vendor, eager }: { vendor: Vendor; eager: boolean }) {
  const title = name(vendor);
  const picture = vendor.cover_image || vendor.logo;
  // Only worth a separate badge when the picture above is not already it.
  const logo = vendor.cover_image && vendor.logo ? vendor.logo : null;
  const stars = rating(vendor.rating);
  const category = name(vendor.category);
  const city = name(vendor.city);
  const from = price(vendor.min_price);
  // A shop with no description still gets a line, so every card in a row has
  // the same shape and the rows line up.
  const about =
    excerpt(vendor.description_ar, 90) ||
    `${title}${category ? ` — ${category}` : ''}${city ? ` في ${city}` : ''}.`;

  return (
    <Link
      href={vendorHref(vendor)}
      className="group relative block w-[80%] shrink-0 snap-center rounded-[1.75rem] sm:w-auto"
    >
      {/* A gold glow that blooms behind the card as it lifts. */}
      <span
        className="pointer-events-none absolute -inset-2 rounded-[2rem] bg-gradient-to-b from-brand-accent/55 via-brand/25 to-transparent
                   opacity-0 blur-xl transition-opacity duration-700 group-hover:opacity-100"
        aria-hidden
      />

      {/* The gold hairline frame. */}
      <div
        className="relative h-full rounded-[1.75rem] bg-gradient-to-b from-[#F3D9B1] via-brand-accent/60 to-brand-dark/40 p-px
                   transition-transform duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:-translate-y-2"
      >
        <div className="shine relative flex h-full flex-col overflow-hidden rounded-[calc(1.75rem-1px)] bg-cream-surface">
          {/* ---- the picture, whole ---- */}
          <div className="relative aspect-[4/3] overflow-hidden bg-[#2B1B10]">
            {picture ? (
              <>
                <img
                  src={picture}
                  alt=""
                  aria-hidden
                  loading={eager ? 'eager' : 'lazy'}
                  decoding="async"
                  className="absolute inset-0 h-full w-full scale-125 object-cover opacity-70 blur-xl
                             transition-transform duration-[1400ms] ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:scale-150"
                />
                <img
                  src={picture}
                  alt={title}
                  width={640}
                  height={480}
                  loading={eager ? 'eager' : 'lazy'}
                  decoding="async"
                  className="relative h-full w-full object-contain transition-transform duration-[900ms]
                             ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:scale-[1.05]"
                />
              </>
            ) : (
              <Monogram title={title} />
            )}

            <div
              className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-black/30"
              aria-hidden
            />

            <div className="absolute inset-x-3 top-3 flex items-start justify-between gap-2">
              {/* `!!` because the API sends these as 0 and 1, and `0 && …`
                  renders the 0 — which is where the stray zeros came from. */}
              <div className="flex flex-wrap gap-1.5">
                {!!vendor.is_vip && <Badge>VIP ⭐</Badge>}
                {!!vendor.is_verified && <Badge tone="verified">موثّق ✓</Badge>}
              </div>
              <span
                className="inline-flex shrink-0 items-center gap-1 rounded-full bg-[#2B1B10]/70 px-2.5 py-1 text-[11px]
                           font-black text-[#F3D9B1] ring-1 ring-brand-accent/50 backdrop-blur-sm"
              >
                <Crown className="h-3.5 w-3.5" />
                مميّز
              </span>
            </div>
          </div>

          {/* ---- the facts ---- */}
          <div className="relative flex flex-1 flex-col p-5 pt-4">
            {logo && (
              <span
                className="absolute -top-9 right-5 z-[3] rounded-full bg-gradient-to-br from-[#F3D9B1] via-brand-accent to-brand-dark
                           p-[2.5px] shadow-lift transition-transform duration-700
                           ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:-translate-y-1 group-hover:rotate-6"
              >
                <img
                  src={logo}
                  alt=""
                  width={64}
                  height={64}
                  loading="lazy"
                  decoding="async"
                  className="h-16 w-16 rounded-full border-2 border-cream-surface bg-white object-cover"
                />
              </span>
            )}

            <div className={`min-h-[3.25rem] ${logo ? 'pr-[4.75rem]' : ''}`}>
              <h3 className="line-clamp-1 text-lg font-black text-ink transition-colors group-hover:text-brand-dark">
                {title}
              </h3>
              {(category || city) && (
                <p className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-muted">
                  {category && (
                    <span className="inline-flex items-center gap-1">
                      <TagIcon />
                      {category}
                    </span>
                  )}
                  {city && (
                    <span className="inline-flex items-center gap-1">
                      <PinIcon />
                      {city}
                    </span>
                  )}
                </p>
              )}
            </div>

            <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
              <StarRow value={stars} count={vendor.reviews_count} />
              {from && (
                <span className="rounded-full bg-brand-light/60 px-2.5 py-1 text-[11px] font-black text-brand-dark">
                  يبدأ من {from}
                </span>
              )}
            </div>

            <p className="mt-3 line-clamp-2 min-h-[2.75rem] text-sm leading-relaxed text-ink-muted">
              {about}
            </p>

            <div className="mt-auto pt-4">
              <span
                className="block h-px bg-gradient-to-l from-transparent via-brand-accent/60 to-transparent"
                aria-hidden
              />
              <span className="mt-4 flex items-center justify-between">
                <span className="text-sm font-black text-brand-dark">زيارة الصفحة</span>
                <span
                  className="grid h-9 w-9 place-items-center rounded-full bg-gradient-to-br from-brand-accent to-brand-dark
                             text-white shadow-card transition-transform duration-500
                             ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:-translate-x-1.5 group-hover:scale-110"
                  aria-hidden
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M19 12H5M11 6l-6 6 6 6" />
                  </svg>
                </span>
              </span>
            </div>
          </div>
        </div>
      </div>
    </Link>
  );
}

/** Five stars filled to the rating, or a welcome for a shop with none yet. */
function StarRow({ value, count }: { value: string | null; count?: number | null }) {
  if (!value) {
    return <span className="text-xs font-black text-brand">✨ جديد على أفراحنا</span>;
  }
  const filled = Math.round(Number(value));
  return (
    <span className="inline-flex items-center gap-1.5">
      <span className="flex gap-0.5" aria-hidden>
        {[0, 1, 2, 3, 4].map((k) => (
          <svg key={k} width="14" height="14" viewBox="0 0 24 24" fill={k < filled ? '#E8B33D' : '#E9DCCB'}>
            <path d="M12 2l2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17l-5.9 3.2 1.2-6.6L2.5 9l6.6-.9L12 2z" />
          </svg>
        ))}
      </span>
      <span className="text-xs font-black text-ink">{value}</span>
      {typeof count === 'number' && count > 0 && (
        <span className="text-[11px] text-ink-muted">({count.toLocaleString('ar-EG')})</span>
      )}
    </span>
  );
}

/**
 * For a shop with no picture at all: its initial, in gold, inside a turning
 * ring — instead of the grey "image missing" icon that sat in LV Home's card.
 */
function Monogram({ title }: { title: string }) {
  const initial = Array.from(title.trim())[0] ?? '✦';
  return (
    <div className="relative grid h-full w-full place-items-center bg-gradient-to-br from-[#2B1B10] via-[#4A3020] to-brand-dark">
      <span className="relative grid h-28 w-28 place-items-center">
        <svg
          viewBox="0 0 112 112"
          className="spin-slow absolute inset-0 h-full w-full text-brand-accent/60"
          fill="none"
          stroke="currentColor"
          aria-hidden
        >
          <circle cx="56" cy="56" r="53" strokeWidth="1" strokeDasharray="3 6" />
        </svg>
        <span className="grid h-20 w-20 place-items-center rounded-full border border-brand-accent/60 text-4xl font-black text-[#F3D9B1]">
          {initial}
        </span>
      </span>
    </div>
  );
}

function Crown({ className = '' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor" aria-hidden>
      <path d="M3 8l4.5 4L12 5l4.5 7L21 8l-2 10H5L3 8Z" />
      <rect x="5" y="19.5" width="14" height="2" rx="1" />
    </svg>
  );
}

function TagIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-brand" aria-hidden>
      <path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8Z" />
      <circle cx="7.5" cy="7.5" r="1.5" fill="currentColor" stroke="none" />
    </svg>
  );
}

function PinIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-brand" aria-hidden>
      <path d="M12 21s-7-6.2-7-12a7 7 0 0 1 14 0c0 5.8-7 12-7 12Z" />
      <circle cx="12" cy="9" r="2.5" />
    </svg>
  );
}
