'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

import { cartCount, useCart } from '@/lib/cart';
import { useSession } from '@/lib/session';
import { listBookings, listOrders } from '@/lib/trade';

import { useUnread } from './LiveNotices';
import SignInGate from './SignInGate';

interface Tile {
  href: string;
  icon: string;
  title: string;
  hint: string;
  count?: number | null;
  urgent?: boolean;
}

/**
 * «حسابي» on the site: where to follow what this account asked for, and —
 * for a shop — what customers are waiting on, first.
 */
export default function AccountHome() {
  const { ready, signedIn, user, runsShop, logout } = useSession();
  const router = useRouter();
  const unread = useUnread();
  const cart = useCart();
  const [waiting, setWaiting] = useState<{ bookings: number | null; orders: number | null }>({
    bookings: null,
    orders: null,
  });

  useEffect(() => {
    if (!runsShop) return;
    const count = (p: Promise<unknown[]>) => p.then((l) => l.length).catch(() => null);
    Promise.all([
      count(listBookings('vendor', 'pending')),
      count(listOrders('vendor', 'pending')),
    ]).then(([bookings, orders]) => setWaiting({ bookings, orders }));
  }, [runsShop]);

  if (!ready) return <div className="card mx-auto h-72 max-w-3xl skeleton" />;
  if (!signedIn || !user) {
    return <SignInGate title="سجّل الدخول إلى حسابك" hint="تابع حجوزاتك وطلباتك وإشعاراتك من أي جهاز." />;
  }

  const inbox: Tile[] = runsShop
    ? [
        {
          href: '/account/bookings?view=incoming',
          icon: '📥',
          title: 'الحجوزات الواردة',
          hint: waiting.bookings ? `${waiting.bookings.toLocaleString('ar-EG')} بانتظار ردّك` : 'لا حجوزات بانتظارك',
          count: waiting.bookings,
          urgent: !!waiting.bookings,
        },
        {
          href: '/account/orders?view=incoming',
          icon: '🧾',
          title: 'طلبات المتجر',
          hint: waiting.orders ? `${waiting.orders.toLocaleString('ar-EG')} بانتظار ردّك` : 'لا طلبات بانتظارك',
          count: waiting.orders,
          urgent: !!waiting.orders,
        },
      ]
    : [];

  const mine: Tile[] = [
    { href: '/account/bookings', icon: '🗓️', title: 'مناسباتي', hint: 'حجوزاتك ورد المحلات عليها' },
    { href: '/account/orders', icon: '🛍️', title: 'طلباتي', hint: 'مشترياتك خطوة بخطوة' },
    {
      href: '/account/notifications',
      icon: '🔔',
      title: 'الإشعارات',
      hint: unread ? `${unread.toLocaleString('ar-EG')} غير مقروء` : 'كل جديد يخصّك',
      count: unread,
      urgent: unread > 0,
    },
    {
      href: '/cart',
      icon: '🧺',
      title: 'السلة',
      hint: cartCount(cart) ? `${cartCount(cart).toLocaleString('ar-EG')} قطعة بانتظار الإرسال` : 'فارغة',
      count: cartCount(cart),
    },
  ];

  return (
    <div className="mx-auto max-w-5xl">
      <div className="card grain relative flex flex-wrap items-center gap-4 overflow-hidden p-5 sm:p-6">
        <span
          className="grid h-16 w-16 shrink-0 place-items-center rounded-full bg-gradient-to-br from-brand-accent
                     to-brand-dark text-2xl font-black text-white shadow-[0_8px_20px_rgba(184,131,90,0.4)]"
          aria-hidden
        >
          {user.name?.trim()?.[0] ?? '؟'}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-xs font-bold text-ink-muted">أهلاً،</p>
          <h2 className="truncate text-2xl font-black text-ink">{user.name}</h2>
          {user.phone && <p className="mt-0.5 text-xs text-ink-muted" dir="ltr">{user.phone}</p>}
        </div>
        <button
          type="button"
          onClick={async () => {
            await logout();
            router.push('/');
          }}
          className="btn-ghost !px-4 !py-2"
        >
          تسجيل الخروج
        </button>
      </div>

      {inbox.length > 0 && (
        <section className="mt-8">
          <h3 className="mb-3 text-sm font-black tracking-wide text-brand">طلبات الزبائن</h3>
          <TileGrid tiles={inbox} />
        </section>
      )}

      <section className="mt-8">
        <h3 className="mb-3 text-sm font-black tracking-wide text-brand">متابعتي</h3>
        <TileGrid tiles={mine} />
      </section>

      <p className="mt-8 text-center text-xs text-ink-muted">
        نفس حسابك في تطبيق أفراحنا.{' '}
        <Link href="/app" className="font-bold text-brand-dark hover:underline">حمّل التطبيق</Link>
        {' '}لتصلك الإشعارات على جوالك حتى والموقع مغلق.
      </p>
    </div>
  );
}

function TileGrid({ tiles }: { tiles: Tile[] }) {
  return (
    <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {tiles.map((t) => (
        <li key={t.href}>
          <Link
            href={t.href}
            className={`card card-hover shine group flex h-full flex-col p-5 ${
              t.urgent ? 'ring-2 ring-brand-accent/70' : ''
            }`}
          >
            <span className="flex items-start justify-between">
              <span
                className="grid h-12 w-12 place-items-center rounded-2xl bg-brand-light/70 text-2xl transition-transform
                           duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:-rotate-6 group-hover:scale-110"
                aria-hidden
              >
                {t.icon}
              </span>
              {!!t.count && t.count > 0 && (
                <span
                  className={`rounded-full px-2.5 py-1 text-xs font-black ${
                    t.urgent ? 'bg-sale text-white' : 'bg-brand-light text-brand-dark'
                  }`}
                >
                  {t.count > 99 ? '99+' : t.count.toLocaleString('ar-EG')}
                </span>
              )}
            </span>
            <span className="mt-4 font-black text-ink transition-colors group-hover:text-brand-dark">{t.title}</span>
            <span className={`mt-1 text-sm ${t.urgent ? 'font-bold text-brand-dark' : 'text-ink-muted'}`}>{t.hint}</span>
          </Link>
        </li>
      ))}
    </ul>
  );
}
