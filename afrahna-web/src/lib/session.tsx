'use client';

import {
  createContext, useCallback, useContext, useEffect, useMemo, useState,
} from 'react';

import {
  SESSION_EVENT, SESSION_KEY, call, readSession, unwrapOne, writeSession,
  type SessionUser, type StoredSession,
} from './client-api';

interface SessionValue {
  /** False until the stored session has been read — render nothing yet. */
  ready: boolean;
  user: SessionUser | null;
  signedIn: boolean;
  /** Runs a shop (or the whole platform): has incoming orders and bookings. */
  runsShop: boolean;
  login(phone: string, password: string): Promise<SessionUser>;
  register(input: { name: string; phone: string; password: string }): Promise<SessionUser>;
  logout(): Promise<void>;
}

const Ctx = createContext<SessionValue | null>(null);

/**
 * Who is visiting, for every client component on the page. One per tab; a
 * login or logout in another tab reaches this one through the storage event.
 */
export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<StoredSession | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const sync = () => setSession(readSession());
    const onStorage = (e: StorageEvent) => {
      if (e.key === SESSION_KEY) sync();
    };
    sync();
    setReady(true);
    window.addEventListener(SESSION_EVENT, sync);
    window.addEventListener('storage', onStorage);
    return () => {
      window.removeEventListener(SESSION_EVENT, sync);
      window.removeEventListener('storage', onStorage);
    };
  }, []);

  // The stored user can be days old: refresh it once per visit, so a shop that
  // was just approved sees its inbox without logging out and back in.
  const token = session?.token;
  useEffect(() => {
    if (!token) return;
    call<unknown>('auth/me')
      .then((body) => {
        const user = unwrapOne<SessionUser>(body);
        const current = readSession();
        if (user?.id && current?.token === token) writeSession({ token, user });
      })
      .catch(() => {});
  }, [token]);

  const login = useCallback(async (phone: string, password: string) => {
    const r = await call<{ token: string; user: SessionUser }>('auth/login', {
      method: 'POST',
      body: { phone, password },
    });
    writeSession({ token: r.token, user: r.user });
    return r.user;
  }, []);

  const register = useCallback(
    async (input: { name: string; phone: string; password: string }) => {
      const r = await call<{ token: string; user: SessionUser }>('auth/register', {
        method: 'POST',
        body: { ...input, password_confirmation: input.password },
      });
      writeSession({ token: r.token, user: r.user });
      return r.user;
    },
    [],
  );

  const logout = useCallback(async () => {
    try {
      await call('auth/logout', { method: 'POST' });
    } catch {
      // Forgetting the token here is what matters; the server cleans up later.
    }
    writeSession(null);
  }, []);

  const value = useMemo<SessionValue>(() => {
    const user = session?.user ?? null;
    return {
      ready,
      user,
      signedIn: !!user,
      runsShop: user?.role === 'vendor' || user?.role === 'admin',
      login,
      register,
      logout,
    };
  }, [ready, session, login, register, logout]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useSession(): SessionValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useSession outside SessionProvider');
  return v;
}

/** `/login?next=…` for the page the visitor is on. */
export function loginHref(next?: string): string {
  const here = next ?? (typeof window !== 'undefined'
    ? window.location.pathname + window.location.search
    : '/account');
  return `/login?next=${encodeURIComponent(here)}`;
}
