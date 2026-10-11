'use client';

import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useEffect, useRef, useState } from 'react';

import { errorMessage } from '@/lib/client-api';
import { useSession } from '@/lib/session';
import {
  customerCanCancel, doneMessage, eventDay, listBookings, listOrders, longWhen, money,
  moveBooking, moveOrder, parseDate, refName, shopNextStep, statusLabel, statusTone,
  type Booking, type Order, type TradeKind, type Viewer,
} from '@/lib/trade';

import SignInGate from './SignInGate';
import TradeTimeline from './TradeTimeline';
import { ReasonDialog, Spinner, toast } from './feedback';

type Row = Order | Booking;

interface Pending {
  row: Row;
  to: 'rejected' | 'cancelled';
}

/**
 * «طلباتي» and «مناسباتي»: what this account asked shops for, and — for a
 * shop owner — what customers asked their shop for, with the buttons that
 * answer. Every press reaches the other side as a notification.
 *
 * The list refreshes itself every minute while the page is open, so a
 * customer waiting on a shop sees the answer land without reloading.
 */
export default function TradeBoard({ kind }: { kind: TradeKind }) {
  const { ready, signedIn, runsShop, user } = useSession();
  const params = useSearchParams();
  const router = useRouter();

  const highlightParam = Number(params.get('highlight')) || null;
  const [incoming, setIncoming] = useState(params.get('view') === 'incoming');
  const [rows, setRows] = useState<Row[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<number | null>(null);
  const [pending, setPending] = useState<Pending | null>(null);
  const [highlight, setHighlight] = useState<number | null>(highlightParam);
  const triedOther = useRef(false);

  const viewer: Viewer = incoming ? 'shop' : 'customer';
  const order = kind === 'order';

  const load = useCallback(
    async (quiet = false) => {
      if (!quiet) {
        setRows(null);
        setError(null);
      }
      try {
        const scope = incoming ? 'vendor' : 'customer';
        const list: Row[] = order ? await listOrders(scope) : await listBookings(scope);
        setRows(list);
        setError(null);
      } catch (e) {
        if (!quiet) setError(errorMessage(e));
      }
    },
    [incoming, order],
  );

  useEffect(() => {
    if (ready && signedIn) load();
  }, [ready, signedIn, load]);

  // Quietly pick up the other side's moves while the page is open.
  useEffect(() => {
    if (!signedIn) return;
    const tick = () => {
      if (document.visibilityState === 'visible') load(true);
    };
    const id = window.setInterval(tick, 60_000);
    document.addEventListener('visibilitychange', tick);
    return () => {
      window.clearInterval(id);
      document.removeEventListener('visibilitychange', tick);
    };
  }, [signedIn, load]);

  // A notification about something this account's shop received lands here
  // on the customer tab first; look in the inbox before giving up on it.
  useEffect(() => {
    if (!rows || !highlight || triedOther.current || !runsShop) return;
    if (rows.some((r) => r.id === highlight)) return;
    triedOther.current = true;
    setIncoming((v) => !v);
  }, [rows, highlight, runsShop]);

  // Bring the marked one into view, then let the marking fade.
  useEffect(() => {
    if (!rows || !highlight || !rows.some((r) => r.id === highlight)) return;
    const el = document.getElementById(`${kind}-${highlight}`);
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    const t = window.setTimeout(() => setHighlight(null), 4000);
    return () => window.clearTimeout(t);
  }, [rows, highlight, kind]);

  const switchTo = (next: boolean) => {
    if (next === incoming) return;
    setIncoming(next);
    const q = new URLSearchParams(params.toString());
    q.delete('highlight');
    if (next) q.set('view', 'incoming');
    else q.delete('view');
    router.replace(`?${q.toString()}`, { scroll: false });
  };

  const move = async (row: Row, to: string, reason?: string) => {
    setBusy(row.id);
    try {
      const updated: Row = order
        ? await moveOrder(row.id, to, reason)
        : await moveBooking(row.id, to, reason);
      toast(doneMessage(kind, to, viewer));
      setPending(null);
      // Show the change at once, then let the server's copy (with its history)
      // replace it.
      setRows((list) => list?.map((r) => (r.id === row.id ? { ...r, ...updated } : r)) ?? list);
      load(true);
    } catch (e) {
      toast(errorMessage(e), { tone: 'error' });
    } finally {
      setBusy(null);
    }
  };

  if (!ready) return <BoardSkeleton />;
  if (!signedIn) {
    return (
      <SignInGate
        title={order ? 'سجّل الدخول لمتابعة طلباتك' : 'سجّل الدخول لمتابعة حجوزاتك'}
        hint="كل خطوة يأخذها المتجر تصلك هنا وفي الإشعارات."
      />
    );
  }

  const nounPlural = order ? 'الطلبيات' : 'الحجوزات';

  return (
    <div>
      {runsShop && (
        <div className="mb-6 inline-flex rounded-2xl border border-brand-light bg-white p-1 shadow-card" role="tablist">
          {[
            { v: false, label: order ? 'مشترياتي' : 'حجوزاتي' },
            { v: true, label: order ? 'طلبات واردة' : 'حجوزات واردة' },
          ].map((t) => (
            <button
              key={String(t.v)}
              type="button"
              role="tab"
              aria-selected={incoming === t.v}
              onClick={() => switchTo(t.v)}
              className={`rounded-xl px-5 py-2 text-sm font-black transition-all ${
                incoming === t.v
                  ? 'bg-gradient-to-br from-brand-accent to-brand-dark text-white shadow-[0_6px_16px_rgba(184,131,90,0.35)]'
                  : 'text-ink-muted hover:text-brand-dark'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
      )}

      {error ? (
        <div className="card grid place-items-center gap-3 px-6 py-12 text-center">
          <p className="font-black text-ink">{error}</p>
          <button type="button" onClick={() => load()} className="btn-ghost">
            إعادة المحاولة
          </button>
        </div>
      ) : rows === null ? (
        <BoardSkeleton />
      ) : rows.length === 0 ? (
        <div className="card grid place-items-center gap-2 px-6 py-14 text-center">
          <div className="float text-3xl" aria-hidden>{order ? '🧾' : '🗓️'}</div>
          <p className="font-black text-ink">
            {incoming ? `لا توجد ${nounPlural} واردة بعد` : `لا توجد ${nounPlural} بعد`}
          </p>
          <p className="max-w-sm text-sm text-ink-muted">
            {incoming
              ? 'ستصلك هنا وفي الإشعارات فور طلب أي زبون.'
              : order
                ? 'تصفّح المتجر وأضف ما يعجبك إلى السلة.'
                : 'احجز خدمة من صفحة أي محل وتابع رده من هنا.'}
          </p>
          {!incoming && (
            <Link href={order ? '/products' : '/vendors'} className="btn-primary mt-3">
              {order ? 'تصفّح المتجر' : 'تصفّح المحلات'}
            </Link>
          )}
        </div>
      ) : (
        <ul className="grid gap-5 lg:grid-cols-2 2xl:grid-cols-3">
          {rows.map((row) => (
            <li
              key={row.id}
              id={`${kind}-${row.id}`}
              className={`card overflow-hidden p-4 transition-shadow duration-700 sm:p-5 ${
                highlight === row.id ? 'ring-2 ring-brand-accent shadow-lift' : ''
              }`}
              style={{ animation: 'rise 0.6s cubic-bezier(0.16,1,0.3,1) both' }}
            >
              {order ? (
                <OrderBody order={row as Order} incoming={incoming} />
              ) : (
                <BookingBody booking={row as Booking} incoming={incoming} />
              )}

              <div className="mt-4">
                <TradeTimeline
                  kind={kind}
                  status={row.status}
                  log={row.status_log}
                  createdAt={row.created_at}
                  updatedAt={row.updated_at}
                  viewer={viewer}
                />
              </div>

              <Actions
                kind={kind}
                row={row}
                incoming={incoming}
                ownRow={!incoming || row.user_id === user?.id}
                busy={busy === row.id}
                onMove={(to) => {
                  if (to === 'rejected' || to === 'cancelled') setPending({ row, to });
                  else move(row, to);
                }}
              />
            </li>
          ))}
        </ul>
      )}

      <ReasonDialog
        open={!!pending}
        busy={!!pending && busy === pending.row.id}
        title={pending?.to === 'rejected'
          ? (order ? 'رفض الطلبية' : 'رفض الحجز')
          : (order ? 'إلغاء الطلبية' : 'إلغاء الحجز')}
        message={incoming
          ? 'سيصل ردّك إلى الزبون مباشرة. اكتب سبباً مختصراً إن أمكن.'
          : 'سيتم إبلاغ المتجر بالإلغاء فوراً.'}
        confirm={pending?.to === 'rejected' ? 'تأكيد الرفض' : 'تأكيد الإلغاء'}
        placeholder={incoming
          ? (order ? 'مثال: المنتج غير متوفر حالياً' : 'مثال: التاريخ محجوز مسبقاً')
          : 'مثال: تغيّرت خططي'}
        onCancel={() => setPending(null)}
        onConfirm={(reason) => pending && move(pending.row, pending.to, reason)}
      />
    </div>
  );
}

function StatusPill({ kind, status }: { kind: TradeKind; status: string }) {
  return (
    <span className={`inline-flex shrink-0 items-center rounded-full border px-3 py-1 text-xs font-black ${statusTone(status)}`}>
      {statusLabel(kind, status)}
    </span>
  );
}

function OrderBody({ order, incoming }: { order: Order; incoming: boolean }) {
  const placed = parseDate(order.created_at);
  const address = [refName(order.city), order.area].filter(Boolean).join(' — ')
    + (order.landmark ? `${(order.city || order.area) ? '، ' : ''}بالقرب من ${order.landmark}` : '');

  return (
    <>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="font-black text-ink">طلب #{order.id}</h3>
          {placed && <p className="mt-0.5 text-xs text-ink-muted">{longWhen(placed)}</p>}
        </div>
        <StatusPill kind="order" status={order.status} />
      </div>

      <PartyRow
        incoming={incoming}
        shop={refName(order.vendor) || 'المتجر'}
        customer={order.customer_name}
        phone={order.customer_phone}
      />

      <ul className="mt-3 space-y-1.5 border-t border-brand-light/60 pt-3">
        {(order.items ?? []).map((it, i) => (
          <li key={`${it.product_id}-${i}`} className="flex items-center gap-2 text-sm">
            <span className="rounded-lg bg-brand-light/60 px-2 py-0.5 text-xs font-black text-brand-dark">
              {it.quantity}×
            </span>
            <span className="min-w-0 flex-1 truncate text-ink">{it.name}</span>
            {money(it.subtotal) && <span className="text-xs font-bold text-ink-muted">{money(it.subtotal)}</span>}
          </li>
        ))}
      </ul>

      {address && <p className="mt-2 text-xs text-ink-muted">📍 {address}</p>}
      {order.note && <p className="mt-1 text-xs text-ink-muted">📝 {order.note}</p>}

      <div className="mt-3 flex items-center justify-between rounded-xl bg-cream px-3 py-2">
        <span className="text-xs font-bold text-ink-muted">الإجمالي</span>
        <span className="font-black text-brand-dark">{money(order.total) ?? 'السعر عند الطلب'}</span>
      </div>
    </>
  );
}

function BookingBody({ booking, incoming }: { booking: Booking; incoming: boolean }) {
  return (
    <>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="font-black text-ink">{eventDay(booking.event_date)}</h3>
          <p className="mt-0.5 text-xs text-ink-muted">
            {[
              booking.event_time ? `الساعة ${booking.event_time.slice(0, 5)}` : null,
              booking.guests_count ? `${booking.guests_count.toLocaleString('ar-EG')} مدعو` : null,
              booking.reference,
            ].filter(Boolean).join(' · ')}
          </p>
        </div>
        <StatusPill kind="booking" status={booking.status} />
      </div>

      {booking.service && (
        <p className="mt-3 text-sm font-bold text-ink">🎀 {refName(booking.service)}</p>
      )}

      <PartyRow
        incoming={incoming}
        shop={refName(booking.vendor) || 'المتجر'}
        customer={booking.user?.name}
        phone={booking.user?.phone}
      />

      {booking.notes && <p className="mt-2 text-xs text-ink-muted">📝 {booking.notes}</p>}
      {money(booking.total_price) && (
        <p className="mt-2 font-black text-brand-dark">{money(booking.total_price)}</p>
      )}
    </>
  );
}

/** The other side of the deal: the shop for a customer, the customer (with a
 * way to call them) for a shop. */
function PartyRow({
  incoming,
  shop,
  customer,
  phone,
}: {
  incoming: boolean;
  shop: string;
  customer?: string | null;
  phone?: string | null;
}) {
  if (!incoming) {
    return <p className="mt-3 text-sm font-bold text-brand-dark">🏪 {shop}</p>;
  }
  const wa = phone ? phone.replace(/\D/g, '').replace(/^0/, '970') : '';
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2">
      <span className="text-sm font-bold text-brand-dark">👤 {customer?.trim() || 'زبون'}</span>
      {phone && (
        <>
          <a href={`tel:${phone}`} className="chip chip-hover" dir="ltr">
            📞 {phone}
          </a>
          {wa && (
            <a
              href={`https://wa.me/${wa}`}
              target="_blank"
              rel="noopener noreferrer"
              className="chip chip-hover !border-emerald-200 !bg-emerald-50 !text-emerald-700"
            >
              واتساب
            </a>
          )}
        </>
      )}
    </div>
  );
}

function Actions({
  kind,
  row,
  incoming,
  ownRow,
  busy,
  onMove,
}: {
  kind: TradeKind;
  row: Row;
  incoming: boolean;
  ownRow: boolean;
  busy: boolean;
  onMove: (to: string) => void;
}) {
  if (incoming) {
    const next = shopNextStep(kind, row.status);
    if (!next) return null;
    const pendingRow = row.status === 'pending';
    return (
      <div className="mt-4 flex gap-3">
        <button
          type="button"
          disabled={busy}
          onClick={() => onMove(pendingRow ? 'rejected' : 'cancelled')}
          className="btn flex-1 border border-red-200 bg-white text-sale hover:bg-red-50 disabled:opacity-60"
        >
          {pendingRow ? 'رفض' : 'إلغاء'}
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => onMove(next.to)}
          className="btn-primary flex-[2] disabled:opacity-60"
        >
          {busy ? <Spinner /> : next.label}
        </button>
      </div>
    );
  }

  if (!ownRow || !customerCanCancel(kind, row.status)) return null;
  return (
    <div className="mt-3 flex justify-end">
      <button
        type="button"
        disabled={busy}
        onClick={() => onMove('cancelled')}
        className="rounded-xl px-3 py-2 text-sm font-black text-sale transition-colors hover:bg-red-50 disabled:opacity-60"
      >
        {kind === 'order' ? 'إلغاء الطلبية' : 'إلغاء الحجز'}
      </button>
    </div>
  );
}

function BoardSkeleton() {
  return (
    <div className="grid gap-5 lg:grid-cols-2 2xl:grid-cols-3" aria-hidden>
      {[0, 1, 2].map((i) => (
        <div key={i} className="card space-y-3 p-5">
          <div className="skeleton h-5 w-1/3 rounded-lg" />
          <div className="skeleton h-4 w-1/2 rounded-lg" />
          <div className="skeleton h-24 w-full rounded-2xl" />
        </div>
      ))}
    </div>
  );
}
