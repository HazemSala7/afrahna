'use client';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';

import { errorMessage } from '@/lib/client-api';
import { useSession } from '@/lib/session';
import {
  listNotices, markAllNoticesRead, markNoticeRead, noticeHref, parseDate, shortWhen,
  type Notice,
} from '@/lib/trade';

import { resetUnread, useUnread } from './LiveNotices';
import SignInGate from './SignInGate';
import { toast } from './feedback';

type ShopLinks = { vendors: Record<string, string>; products: Record<string, string> };

const ICON: Record<string, string> = {
  booking: '🗓️',
  order: '🧾',
  promo: '🏷️',
  points: '⭐',
  reward: '🎁',
  invitation: '💌',
  review: '💬',
  follow: '👥',
  payment: '💳',
  subscription: '💳',
  post: '🖼️',
  comment: '💬',
};

/** The notifications list: newest first, unread marked, each one a way in. */
export default function NoticeList() {
  const { ready, signedIn } = useSession();
  const unread = useUnread();
  const [items, setItems] = useState<Notice[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [links, setLinks] = useState<ShopLinks | null>(null);
  const [permission, setPermission] = useState<NotificationPermission | 'unsupported'>('unsupported');

  const load = useCallback(async () => {
    try {
      setItems(await listNotices());
      setError(null);
    } catch (e) {
      setError(errorMessage(e));
    }
  }, []);

  useEffect(() => {
    if (ready && signedIn) load();
  }, [ready, signedIn, load, unread]);

  useEffect(() => {
    fetch('/shop-links.json')
      .then((r) => (r.ok ? r.json() : null))
      .then(setLinks)
      .catch(() => {});
    if (typeof Notification !== 'undefined') setPermission(Notification.permission);
  }, []);

  if (!ready) return <div className="card mx-auto h-72 max-w-3xl skeleton" />;
  if (!signedIn) {
    return <SignInGate title="سجّل الدخول لرؤية إشعاراتك" hint="ردود المحلات على حجوزاتك وطلباتك تصلك هنا." />;
  }

  const open = async (n: Notice) => {
    if (n.read_at) return;
    setItems((list) => list?.map((x) => (x.id === n.id ? { ...x, read_at: new Date().toISOString() } : x)) ?? list);
    resetUnread(Math.max(0, unread - 1));
    try {
      await markNoticeRead(n.id);
    } catch {
      // Marking read is a nicety; the tap still goes where it should.
    }
  };

  const readAll = async () => {
    try {
      await markAllNoticesRead();
      resetUnread(0);
      setItems((list) => list?.map((x) => ({ ...x, read_at: x.read_at ?? new Date().toISOString() })) ?? list);
    } catch (e) {
      toast(errorMessage(e), { tone: 'error' });
    }
  };

  const allow = async () => {
    if (typeof Notification === 'undefined') return;
    const p = await Notification.requestPermission();
    setPermission(p);
    if (p === 'granted') toast('ستصلك تنبيهات المتصفح', { body: 'طالما الموقع مفتوح في أحد التبويبات.' });
  };

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm font-bold text-ink-muted">
          {unread ? `${unread.toLocaleString('ar-EG')} غير مقروء` : 'لا جديد غير مقروء'}
        </p>
        <div className="flex flex-wrap gap-2">
          {permission === 'default' && (
            <button type="button" onClick={allow} className="btn-ghost !px-4 !py-2">
              🔔 فعّل تنبيهات المتصفح
            </button>
          )}
          {unread > 0 && (
            <button type="button" onClick={readAll} className="btn-ghost !px-4 !py-2">
              تعليم الكل كمقروء
            </button>
          )}
        </div>
      </div>

      {error ? (
        <div className="card grid place-items-center gap-3 px-6 py-12 text-center">
          <p className="font-black text-ink">{error}</p>
          <button type="button" onClick={load} className="btn-ghost">إعادة المحاولة</button>
        </div>
      ) : items === null ? (
        <div className="grid gap-3" aria-hidden>
          {[0, 1, 2, 3].map((i) => <div key={i} className="card h-20 skeleton" />)}
        </div>
      ) : items.length === 0 ? (
        <div className="card grid place-items-center gap-2 px-6 py-14 text-center">
          <div className="float text-3xl" aria-hidden>🔔</div>
          <p className="font-black text-ink">لا إشعارات بعد</p>
          <p className="max-w-sm text-sm text-ink-muted">عندما يرد محل على حجزك أو طلبك ستجد الخبر هنا.</p>
        </div>
      ) : (
        <ul className="grid gap-3">
          {items.map((n) => {
            const href = noticeHref(n, links);
            const when = parseDate(n.created_at);
            const body = (
              <>
                <span
                  className={`grid h-11 w-11 shrink-0 place-items-center rounded-2xl text-xl ${
                    n.read_at ? 'bg-cream' : 'bg-brand-light'
                  }`}
                  aria-hidden
                >
                  {ICON[n.type ?? ''] ?? '🔔'}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-start justify-between gap-3">
                    <span className={`text-[15px] ${n.read_at ? 'font-bold text-ink' : 'font-black text-ink'}`}>
                      {n.title_ar || 'إشعار'}
                    </span>
                    {when && <span className="shrink-0 text-[11px] text-ink-muted">{shortWhen(when)}</span>}
                  </span>
                  {n.body_ar && (
                    <span className="mt-1 block whitespace-pre-line text-sm leading-relaxed text-ink-muted">{n.body_ar}</span>
                  )}
                </span>
                {!n.read_at && (
                  <span className="mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full bg-brand-accent twinkle" aria-label="غير مقروء" />
                )}
              </>
            );
            const cls = `card flex items-start gap-3 p-4 transition-all ${
              n.read_at ? '' : 'ring-1 ring-brand-accent/50'
            } ${href ? 'card-hover' : ''}`;
            return (
              <li key={n.id} style={{ animation: 'rise 0.5s cubic-bezier(0.16,1,0.3,1) both' }}>
                {href ? (
                  <Link href={href} className={cls} onClick={() => open(n)}>
                    {body}
                  </Link>
                ) : (
                  <button type="button" className={`${cls} w-full text-right`} onClick={() => open(n)}>
                    {body}
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
