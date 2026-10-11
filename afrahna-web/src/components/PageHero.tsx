import { Aurora, Flourish, Sparkles } from './decor';
import { Reveal } from './motion';

/**
 * The banner at the top of every inner page.
 *
 * Before this, each listing page opened with a bare `<h1>` on cream and the
 * site's character stopped at the bottom of the home page. One component means
 * a category page, a city page and the shop all open the same way — which is
 * most of what "designed" means on a site with forty pages.
 *
 * A rounded band inside the container rather than a full-bleed section, so it
 * drops into the existing pages without moving anything else.
 */
export default function PageHero({
  title,
  subtitle,
  kicker,
  children,
}: {
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  /** Three words above the heading — the section this page belongs to. */
  kicker?: string;
  /** Chips, filters, a button: anything that belongs under the subtitle. */
  children?: React.ReactNode;
}) {
  return (
    <div
      className="grain relative mb-8 overflow-hidden rounded-[2rem] border border-brand-light
                 bg-gradient-to-bl from-cream-surface via-cream to-brand-light/50
                 px-5 py-10 text-center shadow-card sm:px-10 sm:py-14"
    >
      <Aurora />
      <Sparkles count={9} />

      <div className="relative">
        <Reveal kind="pop">
          <Flourish className="mx-auto w-32 opacity-70" />
        </Reveal>

        {kicker && (
          <Reveal delay={60}>
            <p className="mt-4 text-xs font-black uppercase tracking-[0.25em] text-brand">
              {kicker}
            </p>
          </Reveal>
        )}

        <Reveal delay={110}>
          <h1 className="mt-3 text-3xl font-black leading-tight text-ink sm:text-5xl">
            {title}
          </h1>
        </Reveal>

        {subtitle && (
          <Reveal delay={180}>
            <p className="mx-auto mt-3 max-w-2xl text-sm leading-relaxed text-ink-muted sm:text-base">
              {subtitle}
            </p>
          </Reveal>
        )}

        {children && <Reveal delay={240}>{children}</Reveal>}
      </div>
    </div>
  );
}
