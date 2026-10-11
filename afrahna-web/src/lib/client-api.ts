'use client';

import { API_BASE } from './api';

/**
 * The browser's side of the API: everything a signed-in visitor does —
 * booking, ordering, following, answering — goes through here.
 *
 * The rest of the site is built ahead of time from public data (see api.ts).
 * This file is the only place that holds a member's token, and it keeps it in
 * localStorage: the site is static, served from a different domain than the
 * API, so there is no server of its own to hold a cookie session.
 */

const KEY = 'afrahna.session';

/** Fired on this tab whenever the session is written, so every hook re-reads. */
export const SESSION_EVENT = 'afrahna:session';

export interface SessionUser {
  id: number;
  name: string;
  phone?: string | null;
  email?: string | null;
  /** customer | vendor | admin | delegate */
  role?: string | null;
  avatar?: string | null;
  points_balance?: number | null;
  city_id?: number | null;
}

export interface StoredSession {
  token: string;
  user: SessionUser;
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly errors?: Record<string, string[]>,
  ) {
    super(message);
  }
}

export function readSession(): StoredSession | null {
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as StoredSession;
    return s && typeof s.token === 'string' && s.user ? s : null;
  } catch {
    return null;
  }
}

export function writeSession(s: StoredSession | null): void {
  try {
    if (s) window.localStorage.setItem(KEY, JSON.stringify(s));
    else window.localStorage.removeItem(KEY);
  } catch {
    // Private mode with storage off: the visit still works, it just forgets.
  }
  window.dispatchEvent(new Event(SESSION_EVENT));
}

export const SESSION_KEY = KEY;

/**
 * The API validates in English; the site reads in Arabic. The few messages a
 * visitor can actually trigger get their own words, the rest a plain one.
 */
function arabicValidation(errors: Record<string, string[]>): string {
  const [field, messages] = Object.entries(errors)[0] ?? [];
  const first = (messages?.[0] ?? '').toLowerCase();
  if (field === 'phone' && first.includes('taken')) return 'رقم الجوال مسجّل مسبقاً — سجّل الدخول بدلاً من ذلك';
  if (field === 'email' && first.includes('taken')) return 'البريد الإلكتروني مستخدم مسبقاً';
  if (field === 'password' && first.includes('confirm')) return 'كلمتا المرور غير متطابقتين';
  if (field === 'event_date') return 'اختر تاريخاً اليوم أو بعده';
  if (field?.startsWith('items')) return 'بعض المنتجات لم تعد متوفرة — حدّث السلة وحاول مجدداً';
  const names: Record<string, string> = {
    name: 'الاسم', phone: 'رقم الجوال', password: 'كلمة المرور', email: 'البريد الإلكتروني',
    area: 'المنطقة', city_id: 'المدينة', status: 'الحالة', reason: 'السبب',
  };
  return names[field ?? ''] ? `تحقّق من حقل «${names[field!]}»` : 'تحقّق من البيانات المدخلة';
}

type Query = Record<string, string | number | undefined>;

export async function call<T>(
  path: string,
  opts: { method?: string; body?: unknown; query?: Query } = {},
): Promise<T> {
  const url = new URL(`${API_BASE}/${path}`);
  for (const [k, v] of Object.entries(opts.query ?? {})) {
    if (v !== undefined && v !== '') url.searchParams.set(k, String(v));
  }

  const session = readSession();
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
  if (session?.token) headers.Authorization = `Bearer ${session.token}`;

  let res: Response;
  try {
    res = await fetch(url, {
      method: opts.method ?? 'GET',
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      cache: 'no-store',
    });
  } catch {
    throw new ApiError('تعذّر الاتصال بالخادم. تحقّق من الإنترنت وحاول مجدداً.', 0);
  }

  const text = await res.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }

  if (res.status === 401 && session?.token) {
    // The token was revoked (logged out elsewhere, account removed): forget it
    // rather than failing every request that follows.
    writeSession(null);
  }

  if (!res.ok) {
    const body = (data ?? {}) as { message?: string; errors?: Record<string, string[]> };
    let message = body.message || 'حدث خطأ غير متوقع، حاول مجدداً';
    if (res.status === 422 && body.errors) message = arabicValidation(body.errors);
    else if (res.status === 401 && !path.startsWith('auth/login')) message = 'انتهت الجلسة — سجّل الدخول من جديد';
    else if (res.status === 429) message = 'طلبات كثيرة خلال وقت قصير — انتظر لحظة وحاول مجدداً';
    else if (res.status >= 500) message = 'الخادم مشغول حالياً، حاول بعد قليل';
    throw new ApiError(message, res.status, body.errors);
  }

  return data as T;
}

/** `{data: [...]}`, a paginator, or a bare array — all read as the array. */
export function unwrapList<T>(body: unknown): T[] {
  if (Array.isArray(body)) return body as T[];
  const data = (body as { data?: unknown } | null)?.data;
  return Array.isArray(data) ? (data as T[]) : [];
}

/** `{data: {...}}` or the object itself. */
export function unwrapOne<T>(body: unknown): T {
  const data = (body as { data?: unknown } | null)?.data;
  return (data && typeof data === 'object' && !Array.isArray(data) ? data : body) as T;
}

export function errorMessage(e: unknown): string {
  return e instanceof Error ? e.message : 'حدث خطأ غير متوقع';
}
