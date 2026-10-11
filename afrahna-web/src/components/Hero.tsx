import HeroSlider, { type Slide } from './HeroSlider';
import { Aurora, Petals, Sparkles } from './decor';

/**
 * The first screen: the banners, across the full width.
 *
 * On the same gutters as everything else on the site, so the banner's edges
 * line up with the header's above it and the sections below it. The atmosphere
 * behind shows in those gutters and in the gap before the featured band.
 *
 * The page's <h1> is not in here — it lives in the page itself, so it is still
 * there on a day with no banners to show.
 */
export default function Hero({ slides }: { slides: Slide[] }) {
  if (slides.length === 0) return null;

  return (
    <section className="grain relative overflow-hidden pb-12 sm:pb-14">
      <div className="absolute inset-0 bg-gradient-to-b from-cream-surface via-cream to-cream-deep/60" />
      <Aurora />
      <Sparkles count={12} />
      <Petals count={10} />

      <div className="container-site relative pt-4 sm:pt-6">
        <HeroSlider slides={slides} />

        {/* A wax seal pressed onto the corner of the banner, half on and half
            off, turning slowly — so the frame never reads as a plain box. */}
        <div
          className="pointer-events-none absolute -bottom-9 left-8 z-10 hidden h-[88px] w-[88px] place-items-center sm:grid lg:left-14 2xl:left-20"
          aria-hidden
        >
          <svg
            viewBox="0 0 88 88"
            className="spin-slow absolute inset-0 h-full w-full text-brand"
            fill="none"
            stroke="currentColor"
          >
            <circle cx="44" cy="44" r="41" strokeWidth="1.2" strokeDasharray="3 5" />
          </svg>
          <span className="float grid h-[72px] w-[72px] place-items-center rounded-full border border-brand-light bg-cream-surface text-center shadow-lift">
            <span className="text-[10px] font-black leading-tight text-brand-dark">
              موثوق
              <br />
              من أفراحنا
            </span>
          </span>
        </div>
      </div>
    </section>
  );
}
