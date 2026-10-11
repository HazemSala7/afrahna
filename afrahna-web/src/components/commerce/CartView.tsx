'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

import {
  cartCount, clearShop, setQuantity, shopTotal, useCart, type CartShop,
} from '@/lib/cart';
import { call, errorMessage, unwrapList } from '@/lib/client-api';
import { loginHref, useSession } from '@/lib/session';
import { money, placeOrder, type Order } from '@/lib/trade';

import { Modal, Spinner, toast } from '../account/feedback';

interface City {
  id: number;
  name_ar?: string | null;
  name_en?: string | null;
}

interface Delivery {
  name: string;
  phone: string;
  cityId: number | '';
  area: string;
  landmark: string;
}

const DELIVERY_KEY = 'afrahna.delivery';

function loadDelivery(): Partial<Delivery> {
  try {
    return JSON.parse(window.localStorage.getItem(DELIVERY_KEY) ?? '{}') as Partial<Delivery>;
  } catch {
    return {};
  }
}

/**
 * The basket: grouped by shop, because each shop gets its own order. Sending
 * one reaches that shop at once — in its app and on this site — and the
 * visitor follows it from «طلباتي».
 *
 * There is no payment here, as in the app: the order is an invoice the shop
 * confirms and delivers.
 */
export default function CartView() {
  const cart = useCart();
  const { ready, signedIn, user } = useSession();
  const [checkout, setCheckout] = useState<CartShop | null>(null);
  const [sent, setSent] = useState<{ order: Order; shop: string } | null>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  if (!mounted) return <div className="card h-72 skeleton" />;

  if (cart.length === 0 && !sent) {
    return (
      <div className="card grid place-items-center gap-2 px-6 py-16 text-center">
        <div className="float text-4xl" aria-hidden>🧺</div>
        <p className="text-lg font-black text-ink">سلتك فارغة</p>
        <p className="max-w-sm text-sm text-ink-muted">تصفّح منتجات المحلات وأضف ما يعجبك، ثم أرسل طلبك من هنا.</p>
        <Link href="/products" className="btn-primary mt-3">تصفّح المتجر</Link>
      </div>
    );
  }

  const beginCheckout = (shop: CartShop) => {
    if (ready && !signedIn) {
      window.location.href = loginHref('/cart');
      return;
    }
    setCheckout(shop);
  };

  return (
    <div className="grid gap-6">
      {sent && (
        <div className="card grain relative overflow-hidden border border-emerald-200 p-5 sm:p-6" style={{ animation: 'pop-in 0.6s cubic-bezier(0.34,1.56,0.64,1) both' }}>
          <div className="flex flex-wrap items-center gap-4">
            <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full bg-emerald-50 text-2xl text-emerald-600">✓</span>
            <div className="min-w-0 flex-1">
              <p className="text-lg font-black text-ink">وصلت طلبيتك إلى {sent.shop}</p>
              <p className="mt-1 text-sm text-ink-muted">سنُعلمك فور تأكيدها، وبكل خطوة بعدها حتى تستلمها.</p>
            </div>
            <Link href={`/account/orders?highlight=${sent.order.id}`} className="btn-primary">
              تابع طلبيتك
            </Link>
          </div>
        </div>
      )}

      {cart.length > 0 && (
        <p className="text-sm font-bold text-ink-muted">
          {cartCount(cart).toLocaleString('ar-EG')} قطعة من {cart.length.toLocaleString('ar-EG')}{' '}
          {cart.length === 1 ? 'محل' : 'محلات'} — كل محل يصله طلبه وحده.
        </p>
      )}

      {cart.map((shop) => {
        const total = shopTotal(shop);
        return (
          <section key={shop.vendorId} className="card overflow-hidden" style={{ animation: 'rise 0.5s cubic-bezier(0.16,1,0.3,1) both' }}>
            <header className="flex flex-wrap items-center justify-between gap-3 border-b border-brand-light/60 bg-cream-surface px-5 py-4">
              <h2 className="font-black text-ink">
                🏪{' '}
                {shop.vendorHref ? (
                  <Link href={shop.vendorHref} className="hover:text-brand-dark hover:underline">{shop.vendorName}</Link>
                ) : shop.vendorName}
              </h2>
              <button
                type="button"
                onClick={() => clearShop(shop.vendorId)}
                className="text-xs font-bold text-ink-muted hover:text-sale"
              >
                إزالة الكل
              </button>
            </header>

            <ul className="divide-y divide-brand-light/50">
              {shop.lines.map((l) => (
                <li key={l.productId} className="flex items-center gap-3 px-5 py-3">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  {l.image ? <img src={l.image} alt="" width={56} height={56} className="h-14 w-14 shrink-0 rounded-xl object-cover" loading="lazy" />
                    : <span className="grid h-14 w-14 shrink-0 place-items-center rounded-xl bg-cream text-xl" aria-hidden>🎁</span>}
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-bold text-ink">{l.name}</p>
                    <p className="text-sm font-black text-brand-dark">{money(l.price) ?? 'السعر عند الطلب'}</p>
                  </div>
                  <div className="flex items-center rounded-xl border border-brand-light bg-white">
                    <button type="button" onClick={() => setQuantity(shop.vendorId, l.productId, l.quantity + 1)} className="grid h-9 w-9 place-items-center font-black text-brand-dark" aria-label="زيادة">+</button>
                    <span className="w-7 text-center text-sm font-black">{l.quantity.toLocaleString('ar-EG')}</span>
                    <button type="button" onClick={() => setQuantity(shop.vendorId, l.productId, l.quantity - 1)} className="grid h-9 w-9 place-items-center font-black text-brand-dark" aria-label={l.quantity === 1 ? 'إزالة' : 'إنقاص'}>
                      {l.quantity === 1 ? '🗑' : '−'}
                    </button>
                  </div>
                </li>
              ))}
            </ul>

            <footer className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
              <div>
                <p className="text-xs font-bold text-ink-muted">الإجمالي التقريبي</p>
                <p className="text-xl font-black text-brand-dark">{money(total) ?? 'يحدّده المحل'}</p>
              </div>
              <button type="button" onClick={() => beginCheckout(shop)} className="btn-primary">
                أرسل الطلب إلى {shop.vendorName}
              </button>
            </footer>
          </section>
        );
      })}

      <CheckoutDialog
        shop={checkout}
        user={user}
        onClose={() => setCheckout(null)}
        onSent={(order, shop) => {
          clearShop(shop.vendorId);
          setCheckout(null);
          setSent({ order, shop: shop.vendorName });
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }}
      />
    </div>
  );
}

function CheckoutDialog({
  shop,
  user,
  onClose,
  onSent,
}: {
  shop: CartShop | null;
  user: { name: string; phone?: string | null } | null;
  onClose: () => void;
  onSent: (order: Order, shop: CartShop) => void;
}) {
  const [cities, setCities] = useState<City[]>([]);
  const [form, setForm] = useState<Delivery>({ name: '', phone: '', cityId: '', area: '', landmark: '' });
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!shop) return;
    const saved = loadDelivery();
    setForm({
      name: saved.name || user?.name || '',
      phone: saved.phone || user?.phone || '',
      cityId: saved.cityId ?? '',
      area: saved.area ?? '',
      landmark: saved.landmark ?? '',
    });
    setError(null);
    if (cities.length === 0) {
      call<unknown>('cities', { query: { per_page: 200 } })
        .then((b) => setCities(unwrapList<City>(b)))
        .catch(() => {});
    }
  }, [shop, user, cities.length]);

  if (!shop) return null;

  const set = <K extends keyof Delivery>(k: K, v: Delivery[K]) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.cityId || !form.area.trim()) {
      setError('اختر المدينة واكتب المنطقة — المحل يحتاجهما للتوصيل');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const order = await placeOrder({
        vendor_id: shop.vendorId,
        items: shop.lines.map((l) => ({ product_id: l.productId, quantity: l.quantity })),
        customer_name: form.name.trim() || undefined,
        customer_phone: form.phone.trim() || undefined,
        city_id: Number(form.cityId),
        area: form.area.trim(),
        landmark: form.landmark.trim() || undefined,
        note: note.trim() || undefined,
      });
      try {
        window.localStorage.setItem(DELIVERY_KEY, JSON.stringify(form));
      } catch {
        // Next time the address is typed again. That is all.
      }
      setNote('');
      onSent(order, shop);
      toast('تم إرسال طلبك', { body: `إلى ${shop.vendorName}`, href: `/account/orders?highlight=${order.id}` });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const total = shopTotal(shop);

  return (
    <Modal open={!!shop} onClose={onClose} title={`إتمام الطلب من ${shop.vendorName}`} wide>
      <form onSubmit={submit} className="grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="block">
            <span className="mb-1.5 block text-xs font-black text-ink">الاسم</span>
            <input value={form.name} onChange={(e) => set('name', e.target.value)} autoComplete="name" className="field" />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-xs font-black text-ink">رقم الجوال</span>
            <input value={form.phone} onChange={(e) => set('phone', e.target.value)} inputMode="tel" dir="ltr" autoComplete="tel" className="field text-left" />
          </label>
          <label className="block">
            <span className="mb-1.5 block text-xs font-black text-ink">المدينة *</span>
            <select value={form.cityId} onChange={(e) => set('cityId', e.target.value ? Number(e.target.value) : '')} className="field">
              <option value="">اختر المدينة</option>
              {cities.map((c) => (
                <option key={c.id} value={c.id}>{c.name_ar || c.name_en}</option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="mb-1.5 block text-xs font-black text-ink">المنطقة / الحي *</span>
            <input value={form.area} onChange={(e) => set('area', e.target.value)} placeholder="مثال: الماصيون" className="field" />
          </label>
        </div>
        <label className="block">
          <span className="mb-1.5 block text-xs font-black text-ink">علامة مميزة قريبة (اختياري)</span>
          <input value={form.landmark} onChange={(e) => set('landmark', e.target.value)} placeholder="مثال: مقابل مخبز الأصيل" className="field" />
        </label>
        <label className="block">
          <span className="mb-1.5 block text-xs font-black text-ink">ملاحظة للمحل (اختياري)</span>
          <textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} className="field resize-none" />
        </label>

        <div className="rounded-2xl bg-cream p-4">
          <ul className="space-y-1 text-sm">
            {shop.lines.map((l) => (
              <li key={l.productId} className="flex justify-between gap-3">
                <span className="truncate text-ink">{l.quantity.toLocaleString('ar-EG')}× {l.name}</span>
                <span className="shrink-0 text-ink-muted">{money(l.price === null ? null : l.price * l.quantity) ?? '—'}</span>
              </li>
            ))}
          </ul>
          <p className="mt-3 flex justify-between border-t border-brand-light pt-3 font-black">
            <span className="text-ink">الإجمالي</span>
            <span className="text-brand-dark">{money(total) ?? 'يحدّده المحل'}</span>
          </p>
          <p className="mt-2 text-[11px] leading-relaxed text-ink-muted">
            الدفع عند الاستلام. يعتمد المحل السعر النهائي ويؤكّد طلبك — وسنُعلمك بكل خطوة.
          </p>
        </div>

        {error && <p className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-bold text-sale" role="alert">{error}</p>}

        <button type="submit" disabled={busy} className="btn-primary !py-3.5 disabled:opacity-60">
          {busy ? <Spinner /> : 'تأكيد وإرسال الطلب'}
        </button>
      </form>
    </Modal>
  );
}
