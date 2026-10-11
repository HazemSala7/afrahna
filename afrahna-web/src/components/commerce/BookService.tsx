'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

import { errorMessage } from '@/lib/client-api';
import { loginHref, useSession } from '@/lib/session';
import { eventDay, placeBooking, type Booking } from '@/lib/trade';

import { Modal, Spinner } from '../account/feedback';

export interface BookableService {
  id: number;
  name: string;
  price: string | null;
}

function today(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/**
 * Booking a shop's service from its page: the request reaches the shop at
 * once (in the app and on the site), and the visitor follows its answer from
 * «مناسباتي».
 *
 * `variant="hero"` is the big button under the shop's name; `"card"` sits on a
 * single service and books that one.
 */
export default function BookService({
  shop,
  services,
  preselect,
  variant = 'hero',
}: {
  shop: { id: number; name: string };
  services: BookableService[];
  preselect?: number;
  variant?: 'hero' | 'card';
}) {
  const { ready, signedIn, user } = useSession();
  const [open, setOpen] = useState(false);
  const [serviceId, setServiceId] = useState<number | ''>(preselect ?? services[0]?.id ?? '');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [guests, setGuests] = useState('');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<Booking | null>(null);

  useEffect(() => {
    if (open) {
      setError(null);
      setDone(null);
      if (preselect) setServiceId(preselect);
    }
  }, [open, preselect]);

  const start = () => {
    if (ready && !signedIn) {
      window.location.href = loginHref();
      return;
    }
    setOpen(true);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!date) {
      setError('اختر تاريخ المناسبة');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const booking = await placeBooking({
        vendor_id: shop.id,
        service_id: serviceId || undefined,
        event_date: date,
        event_time: time || undefined,
        guests_count: Number(guests) > 0 ? Number(guests) : undefined,
        notes: notes.trim() || undefined,
      });
      setDone(booking);
      setDate('');
      setTime('');
      setGuests('');
      setNotes('');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const trigger = variant === 'hero' ? (
    <button type="button" onClick={start} className="btn-primary !px-7 !py-3.5 text-base">
      <span aria-hidden>🗓️</span>
      احجز موعدك
    </button>
  ) : (
    <button
      type="button"
      onClick={start}
      className="mt-3 w-full rounded-xl border border-brand-light bg-cream py-2 text-sm font-black text-brand-dark
                 transition-all hover:border-brand hover:bg-white"
    >
      احجز هذه الخدمة
    </button>
  );

  return (
    <>
      {trigger}
      <Modal open={open} onClose={() => setOpen(false)} title={done ? 'تم إرسال طلب الحجز' : `حجز لدى ${shop.name}`}>
        {done ? (
          <div className="text-center">
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-emerald-50 text-3xl" style={{ animation: 'pop-in 0.6s cubic-bezier(0.34,1.56,0.64,1) both' }}>
              ✓
            </div>
            <p className="mt-4 font-black text-ink">
              وصل طلبك إلى {shop.name}{done.event_date ? ` ليوم ${eventDay(done.event_date)}` : ''}.
            </p>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">
              سنُعلمك فور رد المتجر — هنا في الموقع وفي تطبيق أفراحنا — ويمكنك متابعة كل خطوة من «مناسباتي».
            </p>
            <div className="mt-6 flex flex-wrap justify-center gap-3">
              <Link href={`/account/bookings?highlight=${done.id}`} className="btn-primary">
                تابع حجزك
              </Link>
              <button type="button" onClick={() => setOpen(false)} className="btn-ghost">
                حسناً
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={submit} className="grid gap-4">
            {services.length > 0 && (
              <label className="block">
                <span className="mb-1.5 block text-xs font-black text-ink">الخدمة</span>
                <select
                  value={serviceId}
                  onChange={(e) => setServiceId(e.target.value ? Number(e.target.value) : '')}
                  className="field"
                >
                  {services.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}{s.price ? ` — ${s.price}` : ''}
                    </option>
                  ))}
                  <option value="">أخرى / استفسار عام</option>
                </select>
              </label>
            )}

            <div className="grid gap-4 sm:grid-cols-2">
              <label className="block">
                <span className="mb-1.5 block text-xs font-black text-ink">تاريخ المناسبة *</span>
                <input type="date" required min={today()} value={date} onChange={(e) => setDate(e.target.value)} className="field" />
              </label>
              <label className="block">
                <span className="mb-1.5 block text-xs font-black text-ink">الوقت (اختياري)</span>
                <input type="time" value={time} onChange={(e) => setTime(e.target.value)} className="field" />
              </label>
            </div>

            <label className="block">
              <span className="mb-1.5 block text-xs font-black text-ink">عدد المدعوين (اختياري)</span>
              <input
                type="number"
                min={1}
                inputMode="numeric"
                value={guests}
                onChange={(e) => setGuests(e.target.value)}
                placeholder="مثال: ٣٠٠"
                className="field"
              />
            </label>

            <label className="block">
              <span className="mb-1.5 block text-xs font-black text-ink">ملاحظات للمحل (اختياري)</span>
              <textarea
                rows={3}
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="أي تفاصيل تساعد المحل على الرد بسرعة"
                className="field resize-none"
              />
            </label>

            {user && (
              <p className="rounded-xl bg-cream px-3 py-2 text-xs text-ink-muted">
                سيتواصل المحل معك باسم <b className="text-ink">{user.name}</b>
                {user.phone ? <> على <span dir="ltr">{user.phone}</span></> : null}.
              </p>
            )}

            {error && <p className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-bold text-sale">{error}</p>}

            <button type="submit" disabled={busy} className="btn-primary !py-3.5 disabled:opacity-60">
              {busy ? <Spinner /> : 'أرسل طلب الحجز'}
            </button>
          </form>
        )}
      </Modal>
    </>
  );
}
