'use client';

import { call, unwrapList, unwrapOne } from './client-api';

/**
 * Bookings and store orders between a customer and a shop — the same life the
 * app shows, with the same words, so someone who books on the site and checks
 * on their phone reads one story.
 *
 * The rules of who may move what live on the server (App\Support\TradeFlow);
 * this file only mirrors what the reader needs to see and press.
 */

export type TradeKind = 'order' | 'booking';
export type Viewer = 'customer' | 'shop';

export interface StatusEvent {
  status: string;
  /** customer | vendor | admin */
  by: string;
  at?: string | null;
  note?: string | null;
}

interface NamedRef {
  id: number;
  name_ar?: string | null;
  name_en?: string | null;
}

export interface OrderItem {
  product_id?: number;
  name: string;
  image?: string | null;
  price?: number | string;
  quantity: number;
  subtotal?: number | string;
}

export interface Order {
  id: number;
  vendor_id: number;
  vendor?: NamedRef | null;
  user_id?: number | null;
  customer_name?: string | null;
  customer_phone?: string | null;
  city?: NamedRef | null;
  area?: string | null;
  landmark?: string | null;
  note?: string | null;
  items?: OrderItem[] | null;
  total?: number | string | null;
  status: string;
  status_log?: StatusEvent[] | null;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface Booking {
  id: number;
  reference?: string | null;
  vendor_id: number;
  vendor?: NamedRef | null;
  service?: NamedRef | null;
  user_id?: number | null;
  user?: { id: number; name?: string | null; phone?: string | null } | null;
  event_date: string;
  event_time?: string | null;
  guests_count?: number | null;
  total_price?: number | string | null;
  notes?: string | null;
  cancellation_reason?: string | null;
  status: string;
  status_log?: StatusEvent[] | null;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface Notice {
  id: number;
  title_ar?: string | null;
  body_ar?: string | null;
  type?: string | null;
  link?: string | null;
  image?: string | null;
  read_at?: string | null;
  created_at?: string | null;
}

// ---------------------------------------------------------------------------
// Steps and words
// ---------------------------------------------------------------------------

export const ORDER_STEPS = ['pending', 'confirmed', 'preparing', 'ready', 'completed'];
export const BOOKING_STEPS = ['pending', 'confirmed', 'completed'];
export const CLOSED = ['completed', 'cancelled', 'rejected'];

export function stepsFor(kind: TradeKind): string[] {
  return kind === 'order' ? ORDER_STEPS : BOOKING_STEPS;
}

export function statusLabel(kind: TradeKind, status: string): string {
  const order = kind === 'order';
  switch (status) {
    case 'pending':
      return 'بانتظار رد المتجر';
    case 'confirmed':
      return order ? 'مؤكّدة' : 'مؤكّد';
    case 'preparing':
      return 'قيد التجهيز';
    case 'ready':
      return 'جاهزة';
    case 'completed':
      return order ? 'مكتملة' : 'مكتمل';
    case 'cancelled':
      return order ? 'ملغاة' : 'ملغي';
    case 'rejected':
      return order ? 'مرفوضة' : 'مرفوض';
  }
  return status;
}

/** Tailwind classes for a status pill. */
export function statusTone(status: string): string {
  switch (status) {
    case 'confirmed':
      return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    case 'preparing':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'ready':
      return 'bg-sky-50 text-sky-700 border-sky-200';
    case 'completed':
      return 'bg-violet-50 text-violet-700 border-violet-200';
    case 'cancelled':
      return 'bg-stone-100 text-stone-600 border-stone-200';
    case 'rejected':
      return 'bg-red-50 text-sale border-red-200';
    default:
      return 'bg-brand-light/60 text-brand-dark border-brand/20';
  }
}

export function stepLabel(kind: TradeKind, step: string): string {
  switch (step) {
    case 'pending':
      return kind === 'order' ? 'أُرسلت' : 'أُرسل';
    case 'confirmed':
      return 'تأكيد';
    case 'preparing':
      return 'تجهيز';
    case 'ready':
      return 'جاهزة';
    case 'completed':
      return kind === 'order' ? 'تسليم' : 'تنفيذ';
  }
  return step;
}

/** One line on what happens next, in the reader's own terms. */
export function nextHint(kind: TradeKind, status: string, viewer: Viewer): string {
  const order = kind === 'order';
  if (viewer === 'shop') {
    switch (status) {
      case 'pending':
        return 'بانتظار ردّك — الزبون يتابع الطلب';
      case 'confirmed':
        return order ? 'الخطوة التالية: بدء التجهيز' : 'الحجز مؤكّد — سجّل تنفيذه بعد المناسبة';
      case 'preparing':
        return 'الخطوة التالية: الطلبية جاهزة';
      case 'ready':
        return 'الخطوة التالية: تسليم الطلبية';
      case 'completed':
        return order ? 'تم تسليم الطلبية' : 'تم تنفيذ الحجز';
    }
    return '';
  }
  switch (status) {
    case 'pending':
      return 'بانتظار رد المتجر — سنُعلمك فور ردّه';
    case 'confirmed':
      return order
        ? 'أكّد المتجر طلبيتك — سنُعلمك عند بدء التجهيز'
        : 'حجزك مؤكّد — نتمنى لك مناسبة سعيدة';
    case 'preparing':
      return 'المتجر يجهّز طلبيتك الآن';
    case 'ready':
      return 'طلبيتك جاهزة — تواصل مع المتجر للاستلام';
    case 'completed':
      return order ? 'تم تسليم طلبيتك — شكراً لك' : 'تم تنفيذ حجزك — شاركنا تقييمك';
  }
  return '';
}

/** «رفض المتجر الطلبية», «ألغيتَ الحجز» — who closed it, to this reader. */
export function closedBy(kind: TradeKind, status: string, by: string | undefined, viewer: Viewer): string {
  const noun = kind === 'order' ? 'الطلبية' : 'الحجز';
  const rejected = status === 'rejected';
  const verb = rejected ? 'رفض' : 'ألغى';
  switch (by) {
    case 'customer':
      return viewer === 'customer' ? `ألغيتَ ${noun}` : `${verb} الزبون ${noun}`;
    case 'vendor':
      return viewer === 'shop' ? `${rejected ? 'رفضتَ' : 'ألغيتَ'} ${noun}` : `${verb} المتجر ${noun}`;
    case 'admin':
      return `${verb} فريق أفراحنا ${noun}`;
  }
  return rejected ? `رُفض ${noun}` : `أُلغي ${noun}`;
}

/** The shop's one step forward from [status], or null when there is none. */
export function shopNextStep(kind: TradeKind, status: string): { to: string; label: string } | null {
  if (kind === 'booking') {
    if (status === 'pending') return { to: 'confirmed', label: 'تأكيد الحجز' };
    if (status === 'confirmed') return { to: 'completed', label: 'تم تنفيذ الحجز' };
    return null;
  }
  switch (status) {
    case 'pending':
      return { to: 'confirmed', label: 'تأكيد الطلبية' };
    case 'confirmed':
      return { to: 'preparing', label: 'بدء التجهيز' };
    case 'preparing':
      return { to: 'ready', label: 'الطلبية جاهزة' };
    case 'ready':
      return { to: 'completed', label: 'تم التسليم' };
  }
  return null;
}

/** Whether the customer may still call it off from here. */
export function customerCanCancel(kind: TradeKind, status: string): boolean {
  return kind === 'order'
    ? status === 'pending' || status === 'confirmed'
    : status === 'pending' || status === 'confirmed';
}

/** What to tell the person who pressed a button. */
export function doneMessage(kind: TradeKind, to: string, viewer: Viewer): string {
  const noun = kind === 'order' ? 'الطلبية' : 'الحجز';
  if (viewer === 'customer') return `تم إلغاء ${noun} وإبلاغ المتجر`;
  switch (to) {
    case 'confirmed':
      return `تم تأكيد ${noun} وإبلاغ الزبون`;
    case 'preparing':
      return 'بدأ التجهيز — أبلغنا الزبون';
    case 'ready':
      return 'الطلبية جاهزة — أبلغنا الزبون';
    case 'completed':
      return kind === 'order' ? 'تم تسليم الطلبية وإبلاغ الزبون' : 'تم تسجيل تنفيذ الحجز وإبلاغ الزبون';
    case 'rejected':
      return `تم رفض ${noun} وإبلاغ الزبون`;
    case 'cancelled':
      return `تم إلغاء ${noun} وإبلاغ الزبون`;
  }
  return 'تم التحديث';
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

export function parseDate(v?: string | null): Date | null {
  if (!v) return null;
  const d = new Date(v.includes('T') || v.includes('Z') ? v : v.replace(' ', 'T'));
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Today: «٣:٤٠ م». Another day: «١٥ سبتمبر». */
export function shortWhen(d: Date): string {
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  return sameDay
    ? d.toLocaleTimeString('ar-EG', { hour: 'numeric', minute: '2-digit' })
    : d.toLocaleDateString('ar-EG', { day: 'numeric', month: 'long' });
}

export function longWhen(d: Date): string {
  return d.toLocaleString('ar-EG', {
    day: 'numeric', month: 'long', year: 'numeric', hour: 'numeric', minute: '2-digit',
  });
}

export function eventDay(v: string): string {
  const d = parseDate(v.slice(0, 10) + 'T12:00:00');
  return d
    ? d.toLocaleDateString('ar-EG', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
    : v;
}

export function money(v: number | string | null | undefined): string | null {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n) || n <= 0) return null;
  return `${n.toLocaleString('ar-EG', { maximumFractionDigits: 2 })} ₪`;
}

export function refName(r?: NamedRef | null): string {
  return (r?.name_ar || r?.name_en || '').trim();
}

// ---------------------------------------------------------------------------
// The API
// ---------------------------------------------------------------------------

/** `customer`: what this account asked for. `vendor`: what its shop received. */
export type Scope = 'customer' | 'vendor';

export async function listOrders(scope: Scope, status?: string): Promise<Order[]> {
  return unwrapList<Order>(await call('orders', { query: { scope, status, per_page: 50 } }));
}

export async function moveOrder(id: number, status: string, reason?: string): Promise<Order> {
  return unwrapOne<Order>(await call(`orders/${id}`, {
    method: 'PUT',
    body: { status, ...(reason?.trim() ? { reason: reason.trim() } : {}) },
  }));
}

export async function placeOrder(input: {
  vendor_id: number;
  items: { product_id: number; quantity: number }[];
  customer_name?: string;
  customer_phone?: string;
  city_id?: number;
  area?: string;
  landmark?: string;
  note?: string;
}): Promise<Order> {
  return unwrapOne<Order>(await call('orders', { method: 'POST', body: input }));
}

export async function listBookings(scope: Scope, status?: string): Promise<Booking[]> {
  return unwrapList<Booking>(await call('bookings', { query: { scope, status, per_page: 50 } }));
}

export async function moveBooking(id: number, status: string, reason?: string): Promise<Booking> {
  return unwrapOne<Booking>(await call(`bookings/${id}`, {
    method: 'PUT',
    body: { status, ...(reason?.trim() ? { cancellation_reason: reason.trim() } : {}) },
  }));
}

export async function placeBooking(input: {
  vendor_id: number;
  service_id?: number;
  event_date: string;
  event_time?: string;
  guests_count?: number;
  notes?: string;
}): Promise<Booking> {
  return unwrapOne<Booking>(await call('bookings', { method: 'POST', body: input }));
}

export async function listNotices(): Promise<Notice[]> {
  return unwrapList<Notice>(await call('notifications', { query: { limit: 60 } }));
}

export async function unreadCount(): Promise<number> {
  const r = await call<{ count?: number }>('notifications/unread-count');
  return typeof r?.count === 'number' ? r.count : 0;
}

export async function markNoticeRead(id: number): Promise<void> {
  await call(`notifications/${id}/read`, { method: 'POST' });
}

export async function markAllNoticesRead(): Promise<void> {
  await call('notifications/read-all', { method: 'POST' });
}

/**
 * Where a notification leads on the site. Links are `entity:id`; orders and
 * bookings open the list with that one marked. Shops and products need their
 * slugged page, which [shopLinks] resolves.
 */
export function noticeHref(
  n: Notice,
  shopLinks?: { vendors: Record<string, string>; products: Record<string, string> } | null,
): string | null {
  const link = (n.link ?? '').trim();
  const [entity, handle] = link.split(':');
  const id = handle ? handle.split(':')[0] : '';
  switch (entity) {
    case 'booking':
      return `/account/bookings${id ? `?highlight=${id}` : ''}`;
    case 'order':
      return `/account/orders${id ? `?highlight=${id}` : ''}`;
    case 'vendor':
    case 'shop':
    case 'promo':
    case 'offer':
    case 'service':
    case 'follow':
    case 'review':
      return (id && shopLinks?.vendors[id]) || '/vendors';
    case 'product':
      return (id && shopLinks?.products[id]) || '/products';
    case 'reel':
      return id ? `/reels?id=${id}` : '/reels';
    case 'points':
    case 'reward':
      return '/points';
    case 'invitation':
      return '/invitations';
  }
  switch (n.type) {
    case 'booking':
      return '/account/bookings';
    case 'order':
      return '/account/orders';
  }
  return null;
}
