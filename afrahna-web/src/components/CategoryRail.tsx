import Link from 'next/link';

import { name, slugify } from '@/lib/format';
import type { Category } from '@/lib/types';

import CategoryIcon from './CategoryIcon';
import { Stagger } from './motion';

/**
 * The category row.
 *
 * It does not scroll itself. An auto-scrolling row of small targets is the one
 * thing on a page that is measurably hard to press: the tile moves out from
 * under the finger between deciding and touching. The tiles arrive one after
 * another when the row is first seen, and after that they hold still until
 * they are pointed at.
 */
export default function CategoryRail({ categories }: { categories: Category[] }) {
  if (categories.length === 0) return null;

  return (
    <Stagger className="rail">
      {categories.map((c) => (
        <Link
          key={c.id}
          href={`/category/${c.slug || slugify(name(c))}-${c.id}`}
          className="group grid w-24 justify-items-center gap-2 text-center"
        >
          <span
            className="relative grid h-[68px] w-[68px] place-items-center overflow-hidden
                       rounded-[1.35rem] border border-brand-light bg-cream-surface
                       text-brand-dark shadow-card transition-all duration-500
                       ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:-translate-y-2
                       group-hover:border-brand group-hover:shadow-lift"
          >
            {/* The tint floods in from the bottom on hover. */}
            <span
              className="absolute inset-0 origin-bottom scale-y-0 bg-gradient-to-t
                         from-brand-light to-brand-light/40 transition-transform
                         duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]
                         group-hover:scale-y-100"
              aria-hidden
            />

            {/* A dashed gold ring that appears and turns while the tile is
                hovered — the tile catching the light as it lifts. */}
            <svg
              viewBox="0 0 68 68"
              className="spin-slow absolute inset-0 h-full w-full text-brand-accent opacity-0
                         transition-opacity duration-500 group-hover:opacity-100"
              fill="none"
              stroke="currentColor"
              aria-hidden
            >
              <rect x="4" y="4" width="60" height="60" rx="18" strokeWidth="1" strokeDasharray="4 7" />
            </svg>

            <span className="relative transition-transform duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:scale-110 group-hover:-rotate-6">
              <CategoryIcon icon={c.icon} title={name(c)} />
            </span>
          </span>

          <span className="line-clamp-2 text-xs font-bold leading-tight text-ink transition-colors group-hover:text-brand-dark">
            {name(c)}
          </span>
        </Link>
      ))}
    </Stagger>
  );
}
