'use client';

import Link from 'next/link';
import { useState } from 'react';

import { addToCart, quantityOf, useCart } from '@/lib/cart';

import { toast } from '../account/feedback';

/**
 * «أضف إلى السلة» on a product page. The page itself is static HTML; only this
 * button is alive, and it remembers what is already in the basket.
 */
export default function AddToCart({
  product,
  shop,
}: {
  product: { id: number; name: string; image?: string | null; price: number | null };
  shop: { id: number; name: string; href?: string | null };
}) {
  const cart = useCart();
  const inCart = quantityOf(cart, product.id);
  const [qty, setQty] = useState(1);
  const [pulse, setPulse] = useState(0);

  const add = () => {
    addToCart(
      { vendorId: shop.id, vendorName: shop.name, vendorHref: shop.href },
      { productId: product.id, name: product.name, image: product.image, price: product.price },
      qty,
    );
    setPulse((p) => p + 1);
    toast('أُضيف إلى السلة', {
      body: `${product.name} × ${qty.toLocaleString('ar-EG')}`,
      href: '/cart',
    });
    setQty(1);
  };

  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="flex items-center rounded-xl border border-brand-light bg-white" aria-label="الكمية">
        <button
          type="button"
          onClick={() => setQty((q) => Math.min(99, q + 1))}
          className="grid h-12 w-11 place-items-center text-lg font-black text-brand-dark hover:bg-cream"
          aria-label="زيادة"
        >
          +
        </button>
        <span className="w-8 text-center font-black text-ink" aria-live="polite">
          {qty.toLocaleString('ar-EG')}
        </span>
        <button
          type="button"
          onClick={() => setQty((q) => Math.max(1, q - 1))}
          className="grid h-12 w-11 place-items-center text-lg font-black text-brand-dark hover:bg-cream"
          aria-label="إنقاص"
        >
          −
        </button>
      </div>

      <button
        key={pulse}
        type="button"
        onClick={add}
        className="btn-primary !py-3.5"
        style={pulse ? { animation: 'pop-in 0.5s cubic-bezier(0.34,1.56,0.64,1)' } : undefined}
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
          strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M5 8h14l-1.2 11.2a1 1 0 0 1-1 .8H7.2a1 1 0 0 1-1-.8L5 8Z" />
          <path d="M9 8V6.5a3 3 0 0 1 6 0V8" />
        </svg>
        أضف إلى السلة
      </button>

      {inCart > 0 && (
        <Link href="/cart" className="chip chip-hover">
          في سلتك {inCart.toLocaleString('ar-EG')} — إتمام الطلب ←
        </Link>
      )}
    </div>
  );
}
