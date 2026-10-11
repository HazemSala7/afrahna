'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';

import HeaderAccount from './account/HeaderAccount';
import { Magnetic } from './motion';

const NAV = [
  { href: '/vendors', label: 'المحلات' },
  { href: '/categories', label: 'التصنيفات' },
  { href: '/products', label: 'المتجر' },
  { href: '/offers', label: 'العروض' },
  { href: '/reels', label: 'ريلز' },
  { href: '/invitations', label: 'الدعوات' },
  { href: '/planning', label: 'خطّطي' },
];

/**
 * The site header: brand, sections, search, and the app link.
 *
 * There is no hamburger. On a phone the sections live in the bottom bar, where
 * the thumb already is — a menu behind an icon you have to guess is there was
 * strictly worse, and keeping both would have meant two places to change every
 * time a section is added.
 *
 * The bar runs the full width of the screen, so from a laptop up it is three
 * columns — brand, sections, actions — with the sections held in the true
 * centre. As a plain row the sections sat against the actions and left a hole
 * in the middle of a wide screen.
 *
 * At the top of the page the bar is part of the hero and has no edges at all;
 * once the page moves it condenses into a frosted strip. That transition is
 * the whole of its behaviour, and it is one boolean.
 */
export default function Header() {
  const pathname = usePathname();
  const [stuck, setStuck] = useState(false);

  useEffect(() => {
    const onScroll = () => setStuck(window.scrollY > 12);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header
      className={`sticky top-0 z-40 transition-all duration-500 ${
        stuck
          ? 'border-b border-brand-light/70 bg-cream/85 shadow-card backdrop-blur-xl'
          : 'border-b border-transparent bg-transparent'
      }`}
    >
      {/* A gold hairline along the bottom edge that draws itself outwards from
          the centre the moment the bar becomes solid. */}
      <span
        className={`pointer-events-none absolute inset-x-0 bottom-0 h-px origin-center
                    bg-gradient-to-l from-transparent via-brand-accent to-transparent
                    transition-transform duration-700 ease-[cubic-bezier(0.16,1,0.3,1)]
                    ${stuck ? 'scale-x-100' : 'scale-x-0'}`}
        aria-hidden
      />

      <div
        className={`container-site flex items-center gap-3 transition-all duration-500
                    lg:grid lg:grid-cols-[1fr_auto_1fr] ${stuck ? 'h-16' : 'h-20'}`}
      >
        <Link href="/" className="group flex shrink-0 items-center gap-2 lg:justify-self-start">
          <span className="relative">
            {/* A gold ring that turns around the mark when it is pointed at. */}
            <svg
              viewBox="0 0 56 56"
              className="spin-slow pointer-events-none absolute -inset-1.5 h-[calc(100%+12px)] w-[calc(100%+12px)]
                         text-brand-accent opacity-0 transition-opacity duration-500 group-hover:opacity-100"
              fill="none"
              stroke="currentColor"
              aria-hidden
            >
              <circle cx="28" cy="28" r="26" strokeWidth="1" strokeDasharray="3 6" />
            </svg>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/logo.png"
              alt=""
              width={44}
              height={44}
              className={`relative rounded-xl object-cover shadow-card transition-all duration-500
                          ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:-rotate-6 group-hover:scale-105
                          ${stuck ? 'h-10 w-10' : 'h-11 w-11'}`}
            />
          </span>
          <span className="flex flex-col leading-tight">
            <span className="text-lg font-black text-brand-dark">أفراحنا</span>
            {/* Folds away once the bar condenses, rather than vanishing. */}
            <span
              className={`hidden overflow-hidden text-[10px] text-ink-muted transition-all
                          duration-500 sm:block ${stuck ? 'max-h-0 opacity-0' : 'max-h-4 opacity-100'}`}
            >
              كل ما يلزم مناسبتك في مكان واحد
            </span>
          </span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex md:mr-auto lg:mr-0 xl:gap-3 2xl:gap-5">
          {NAV.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? 'page' : undefined}
                className={`navlink ${active ? 'text-brand-dark' : 'text-ink hover:text-brand-dark'}`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="mr-auto flex items-center gap-2 sm:gap-3 md:mr-0 lg:justify-self-end">
          <Link
            href="/search"
            className="group flex h-10 w-10 items-center justify-center rounded-full
                       border border-brand-light bg-white/80 text-brand-dark backdrop-blur-sm
                       transition-all duration-300 hover:-translate-y-0.5 hover:border-brand
                       hover:shadow-card"
            aria-label="بحث"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              className="transition-transform duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:scale-110 group-hover:-rotate-12"
              aria-hidden
            >
              <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="2" />
              <path d="M20 20l-3.5-3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
          </Link>

          <HeaderAccount />

          <Magnetic className="hidden xl:inline-block">
            <Link href="/app" className="btn-primary !px-5 !py-2.5">
              حمّل التطبيق
            </Link>
          </Magnetic>
        </div>
      </div>
    </header>
  );
}
