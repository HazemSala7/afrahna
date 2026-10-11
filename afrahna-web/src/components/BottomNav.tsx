'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { useUnread } from './account/LiveNotices';

/**
 * The phone's navigation — the app's bottom bar, on the web.
 *
 * On a phone the top of the screen is the worst place to put navigation and
 * the bottom is the best: it is where the thumb already is. The app has known
 * this for years; the site was still hiding its sections behind a hamburger,
 * which is a menu you have to guess is there.
 *
 * Laid out to match the app exactly, including the raised centre button, so
 * someone who uses both never has to learn a second arrangement. In an RTL row
 * the first child renders at the visual RIGHT, hence: حسابي، خطّطي، الرئيسية،
 * ريلز، المتجر.
 */
interface NavItem {
  href: string;
  label: string;
  icon: string;
  /** The raised middle button. */
  center?: boolean;
}

const ITEMS: NavItem[] = [
  { href: '/account', label: 'حسابي', icon: 'user' },
  { href: '/planning', label: 'خطّطي', icon: 'spark' },
  { href: '/', label: 'الرئيسية', icon: 'home', center: true },
  { href: '/reels', label: 'ريلز', icon: 'reel' },
  { href: '/products', label: 'المتجر', icon: 'store' },
];

export default function BottomNav() {
  const pathname = usePathname();
  const unread = useUnread();

  const isActive = (href: string) =>
    href === '/' ? pathname === '/' : pathname.startsWith(href);

  return (
    <nav
      aria-label="التنقّل السريع"
      className="fixed inset-x-0 bottom-0 z-40 md:hidden"
      style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
    >
      <div className="relative mx-3 mb-3 rounded-[26px] border border-brand-light/80 bg-white/95 shadow-lift backdrop-blur-xl">
        {/* A gold hairline along the top edge of the bar. */}
        <span
          className="pointer-events-none absolute inset-x-8 top-0 h-px bg-gradient-to-l from-transparent via-brand-accent/70 to-transparent"
          aria-hidden
        />

        <ul className="flex h-16 items-center justify-around px-1">
          {ITEMS.map((item) => {
            const active = isActive(item.href);

            if (item.center) {
              return (
                <li key={item.href} className="relative -mt-8">
                  {/* A halo that pulses out of the raised button while it is
                      the page you are on. */}
                  {active && (
                    <span
                      className="pointer-events-none absolute inset-0 rounded-full bg-brand-accent"
                      style={{ animation: 'pulse-ring 2.6s ease-out infinite' }}
                      aria-hidden
                    />
                  )}
                  <Link
                    href={item.href}
                    aria-current={active ? 'page' : undefined}
                    className="relative grid h-14 w-14 place-items-center rounded-full
                               bg-gradient-to-br from-brand-accent to-brand-dark
                               text-white shadow-[0_10px_22px_rgba(184,131,90,0.45)]
                               transition-transform duration-300 active:scale-90"
                  >
                    <Icon name={item.icon} size={24} />
                    <span className="sr-only">{item.label}</span>
                  </Link>
                  <span className="mt-1 block text-center text-[10px] font-black text-brand-dark">
                    {item.label}
                  </span>
                </li>
              );
            }

            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  aria-current={active ? 'page' : undefined}
                  className={`grid w-16 place-items-center gap-1 rounded-xl py-1.5
                              transition-colors active:scale-95 ${
                                active ? 'text-brand-dark' : 'text-ink-muted'
                              }`}
                >
                  <span
                    className={`relative grid h-9 w-9 place-items-center rounded-xl
                                transition-all duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)]
                                ${active ? 'scale-110 bg-brand-light' : 'bg-transparent'}`}
                  >
                    <Icon name={item.icon} size={20} />
                    {/* Something waiting in the account: a shop's answer, a
                        customer's order. */}
                    {item.href === '/account' && unread > 0 && (
                      <span
                        className="absolute -left-0.5 -top-0.5 h-2.5 w-2.5 rounded-full border-2 border-white bg-sale"
                        aria-label={`${unread} إشعار غير مقروء`}
                      />
                    )}
                  </span>
                  <span className="text-[10px] font-black leading-none">{item.label}</span>
                  {/* A gold dot under the section you are in. */}
                  <span
                    className={`h-1 rounded-full bg-brand-dark transition-all duration-500
                                ${active ? 'w-4 opacity-100' : 'w-0 opacity-0'}`}
                    aria-hidden
                  />
                </Link>
              </li>
            );
          })}
        </ul>
      </div>
    </nav>
  );
}

function Icon({ name, size }: { name: string; size: number }) {
  const common = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true,
  };
  switch (name) {
    case 'home':
      return (
        <svg {...common}>
          <path d="M4 11l8-6 8 6v9H4v-9Z" />
          <path d="M9.5 20v-5h5v5" />
        </svg>
      );
    case 'store':
      return (
        <svg {...common}>
          <path d="M4 8h16l-1 12H5L4 8Z" />
          <path d="M9 8V6a3 3 0 0 1 6 0v2" />
        </svg>
      );
    case 'reel':
      return (
        <svg {...common}>
          <rect x="3" y="4" width="18" height="16" rx="3" />
          <path d="M3 9h18M9 4l-2 5M15 4l-2 5" />
          <path d="M11 13.5l3.5 2-3.5 2v-4Z" fill="currentColor" stroke="none" />
        </svg>
      );
    case 'spark':
      return (
        <svg {...common}>
          <path d="M12 3l1.8 4.7L18.5 9.5 13.8 11.3 12 16l-1.8-4.7L5.5 9.5l4.7-1.8L12 3Z" />
          <path d="M18 16.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8.8-2Z" />
        </svg>
      );
    default:
      return (
        <svg {...common}>
          <circle cx="12" cy="8" r="3.6" />
          <path d="M4.5 20a7.5 7.5 0 0 1 15 0" />
        </svg>
      );
  }
}
