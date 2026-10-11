import Link from 'next/link';

import { excerpt, name, rating, vendorHref } from '@/lib/format';
import type { Vendor } from '@/lib/types';

import { Badge, Img, Stars } from './ui';

/**
 * One shop, as it appears in every list on the site.
 *
 * A whole-card link rather than a linked title: the card is what the reader
 * aims at, and a 3-pixel text target inside a 300-pixel card is the kind of
 * thing that reads as "hard to press" long before anyone can say why.
 *
 * Six things move on hover, and all six are the same gesture — the card is
 * picking itself up off the page: it lifts, the photograph leans in, light
 * crosses it, the wash deepens, a gold rule grows under the name, and a "see
 * the shop" line rises from the bottom edge. One idea, not six effects.
 */
export default function VendorCard({
  vendor,
  eager = false,
  className = '',
}: {
  vendor: Vendor;
  eager?: boolean;
  className?: string;
}) {
  const stars = rating(vendor.rating);
  const city = name(vendor.city);
  const category = name(vendor.category);
  const hasLogo = Boolean(vendor.logo && vendor.cover_image);

  return (
    <Link
      href={vendorHref(vendor)}
      className={`card card-hover shine group block overflow-hidden
                  hover:ring-1 hover:ring-brand-light ${className}`}
    >
      {/* Not `overflow-hidden`: the logo below hangs deliberately past the
          bottom edge of the picture, and clipping here cut it in half. The one
          thing that does need clipping — the bar that slides up — carries its
          own clip instead. */}
      <div className="relative">
        <Img
          src={vendor.cover_image || vendor.logo}
          alt={name(vendor)}
          eager={eager}
          ratio="aspect-[16/10]"
        />

        {/* A wash that deepens on hover, so the badges stay readable over any
            photograph without dimming the picture at rest. */}
        <div
          className="pointer-events-none absolute inset-0 bg-gradient-to-t
                     from-black/35 via-transparent to-transparent opacity-70
                     transition-opacity duration-500 group-hover:opacity-100"
        />

        {/* `!!` because the API sends these as 0 and 1, and `0 && …` renders
            the 0 — a stray zero in the corner of every card. */}
        <div className="absolute right-3 top-3 flex gap-1.5">
          {!!vendor.is_vip && <Badge>VIP ⭐</Badge>}
          {!!vendor.is_verified && <Badge tone="verified">موثّق ✓</Badge>}
        </div>

        {/* Rises out of the bottom edge on hover — the card saying what
            pressing it will do, without taking any room when it is at rest. */}
        <span
          className="pointer-events-none absolute inset-x-0 bottom-0 z-[2] block overflow-hidden"
          aria-hidden
        >
          <span
            className="flex translate-y-full items-center justify-center gap-1.5
                       bg-gradient-to-t from-black/75 to-black/25 py-2.5 text-[11px]
                       font-black text-white transition-transform duration-500
                       ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:translate-y-0"
          >
            شوف الصفحة
            <span className="inline-block">←</span>
          </span>
        </span>

        {hasLogo && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={vendor.logo as string}
            alt=""
            width={52}
            height={52}
            loading="lazy"
            decoding="async"
            className="absolute -bottom-6 right-4 z-[3] rounded-xl border-2 border-white bg-white
                       object-cover shadow-card transition-transform duration-500
                       ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:-translate-y-1 group-hover:rotate-3"
            style={{ height: 52, width: 52 }}
          />
        )}
      </div>

      <div className={`p-4 ${hasLogo ? 'pt-8' : ''}`}>
        <div className="flex items-start justify-between gap-2">
          <h3 className="line-clamp-1 text-[15px] font-black text-ink transition-colors group-hover:text-brand-dark">
            {name(vendor)}
          </h3>
          {stars && <Stars value={stars} count={vendor.reviews_count} />}
        </div>

        {(category || city) && (
          <p className="mt-1 line-clamp-1 text-xs text-ink-muted">
            {[category, city].filter(Boolean).join(' · ')}
          </p>
        )}

        {vendor.description_ar && (
          <p className="mt-2 line-clamp-2 text-sm leading-relaxed text-ink-muted">
            {excerpt(vendor.description_ar)}
          </p>
        )}

        <span
          className="mt-4 block h-[3px] w-0 rounded-full bg-gradient-to-l
                     from-brand-accent to-brand-dark transition-[width]
                     duration-500 ease-out group-hover:w-14"
          aria-hidden
        />
      </div>
    </Link>
  );
}
