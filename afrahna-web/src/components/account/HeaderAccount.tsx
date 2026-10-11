'use client';

import Link from 'next/link';

import { cartCount, useCart } from '@/lib/cart';
import { useSession } from '@/lib/session';

import { useUnread } from './LiveNotices';

const round =
  'group relative flex h-10 w-10 items-center justify-center rounded-full border border-brand-light '
  + 'bg-white/80 text-brand-dark backdrop-blur-sm transition-all duration-300 hover:-translate-y-0.5 '
  + 'hover:border-brand hover:shadow-card';

function Count({ n }: { n: number }) {
  if (n <= 0) return null;
  return (
    <span
      className="absolute -left-1 -top-1 grid h-5 min-w-5 place-items-center rounded-full bg-sale px-1 text-[10px]
                 font-black text-white shadow-[0_4px_10px_rgba(193,69,43,0.4)]"
      style={{ animation: 'pop-in 0.4s cubic-bezier(0.34,1.56,0.64,1) both' }}
    >
      {n > 99 ? '99+' : n.toLocaleString('ar-EG')}
    </span>
  );
}

/**
 * The header's member controls: the basket, the bell, and the account. Before
 * a visitor signs in only the basket and a «دخول» link show.
 */
export default function HeaderAccount() {
  const { ready, signedIn, user } = useSession();
  const cart = useCart();
  const unread = useUnread();
  const items = cartCount(cart);

  return (
    <>
      <Link href="/cart" className={round} aria-label={items ? `السلة، ${items} قطعة` : 'السلة'}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
          strokeLinecap="round" strokeLinejoin="round" aria-hidden
          className="transition-transform duration-500 group-hover:-rotate-6 group-hover:scale-110">
          <path d="M5 8h14l-1.2 11.2a1 1 0 0 1-1 .8H7.2a1 1 0 0 1-1-.8L5 8Z" />
          <path d="M9 8V6.5a3 3 0 0 1 6 0V8" />
        </svg>
        <Count n={items} />
      </Link>

      {ready && signedIn && (
        <Link
          href="/account/notifications"
          className={round}
          aria-label={unread ? `الإشعارات، ${unread} غير مقروء` : 'الإشعارات'}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
            strokeLinecap="round" strokeLinejoin="round" aria-hidden
            className={unread ? 'origin-top' : ''}
            style={unread ? { animation: 'swing 2.4s ease-in-out infinite' } : undefined}>
            <path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15L6 16Z" />
            <path d="M10 20a2 2 0 0 0 4 0" />
          </svg>
          <Count n={unread} />
        </Link>
      )}

      {ready && (
        signedIn ? (
          <Link
            href="/account"
            className="hidden h-10 w-10 place-items-center rounded-full bg-gradient-to-br from-brand-accent to-brand-dark sm:grid
                       text-sm font-black text-white shadow-[0_6px_16px_rgba(184,131,90,0.4)] transition-transform
                       duration-300 hover:-translate-y-0.5"
            aria-label="حسابي"
            title={user?.name}
          >
            {(user?.name?.trim()?.[0] ?? '؟').toUpperCase()}
          </Link>
        ) : (
          <Link href="/login" className="btn-ghost hidden !px-4 !py-2.5 sm:inline-flex">
            دخول
          </Link>
        )
      )}
    </>
  );
}
