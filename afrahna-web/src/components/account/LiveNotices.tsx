'use client';

import { useEffect, useRef, useSyncExternalStore } from 'react';

import { useSession } from '@/lib/session';
import { listNotices, noticeHref, unreadCount, type Notice } from '@/lib/trade';

import { toast } from './feedback';

/**
 * Keeps a signed-in visitor up to date while the site is open: the unread
 * count in the header, and — the moment a shop answers or a customer orders —
 * a message on screen and, if they allowed it, one from the browser itself.
 *
 * It asks the API every 45 seconds while the tab is visible, and at once when
 * the tab comes back into view. Nothing runs for a visitor who is not signed
 * in, and nothing runs in a hidden tab.
 */

let unread = 0;
const listeners = new Set<() => void>();

function setUnread(n: number) {
  if (n === unread) return;
  unread = n;
  for (const l of listeners) l();
}

/** The unread count, for the bell. */
export function useUnread(): number {
  return useSyncExternalStore(
    (cb) => {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
    () => unread,
    () => 0,
  );
}

/** For the notifications page, after it marks things read. */
export function resetUnread(n = 0) {
  setUnread(n);
}

const SEEN_KEY = 'afrahna.notices.seen';

function lastSeenId(): number {
  try {
    return Number(window.localStorage.getItem(SEEN_KEY)) || 0;
  } catch {
    return 0;
  }
}

function markSeen(id: number) {
  try {
    window.localStorage.setItem(SEEN_KEY, String(id));
  } catch {
    // Without storage the same notice may be announced twice. Harmless.
  }
}

function announce(n: Notice) {
  const href = noticeHref(n);
  const title = n.title_ar || 'إشعار جديد';
  const body = n.body_ar || undefined;
  toast(title, { tone: 'notice', body, href });

  if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
  if (document.visibilityState === 'visible' && document.hasFocus()) return;
  try {
    const system = new Notification(title, {
      body,
      icon: '/favicon.png',
      tag: n.link || `notice-${n.id}`,
      lang: 'ar',
      dir: 'rtl',
    });
    system.onclick = () => {
      window.focus();
      if (href) window.location.href = href;
      system.close();
    };
  } catch {
    // Some mobile browsers only allow notifications from a service worker.
  }
}

export default function LiveNotices() {
  const { signedIn, user } = useSession();
  const userId = user?.id;
  const busy = useRef(false);

  useEffect(() => {
    if (!signedIn) {
      setUnread(0);
      return;
    }

    let first = true;
    let lastCount = -1;

    const check = async () => {
      if (busy.current || document.visibilityState !== 'visible') return;
      busy.current = true;
      try {
        const count = await unreadCount();
        setUnread(count);
        // Only a rising count can mean something new: the list itself is
        // fetched then, not on every tick someone leaves a notice unread.
        const rose = count > lastCount;
        lastCount = count;
        if (count === 0 || (!first && !rose)) return;

        const seen = lastSeenId();
        const latest = await listNotices();
        const newest = latest.reduce((m, n) => Math.max(m, n.id), 0);

        // The first check of a visit only sets the mark: what arrived while the
        // visitor was away is waiting in the bell, not shouted at them.
        if (!first && seen > 0) {
          latest
            .filter((n) => n.id > seen && !n.read_at)
            .slice(0, 3)
            .reverse()
            .forEach(announce);
        }
        if (newest > seen) markSeen(newest);
      } catch {
        // Offline, or the API is busy: try again on the next tick.
      } finally {
        first = false;
        busy.current = false;
      }
    };

    check();
    const id = window.setInterval(check, 45_000);
    const onVisible = () => {
      if (document.visibilityState === 'visible') check();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      window.clearInterval(id);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [signedIn, userId]);

  return null;
}
