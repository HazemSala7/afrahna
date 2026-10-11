'use client';

import { useSyncExternalStore } from 'react';

/**
 * The basket, kept in the browser until it is sent.
 *
 * An order goes to one shop, so the basket is grouped by shop: someone can
 * collect from three shops and send each its own order. Prices here are what
 * the visitor saw; the server prices every order again from its own records.
 */

const KEY = 'afrahna.cart';
const EVENT = 'afrahna:cart';

export interface CartLine {
  productId: number;
  name: string;
  image?: string | null;
  /** The price shown when it was added, per piece. */
  price: number | null;
  quantity: number;
}

export interface CartShop {
  vendorId: number;
  vendorName: string;
  vendorHref?: string | null;
  lines: CartLine[];
}

type Cart = CartShop[];

const EMPTY: Cart = [];
let cached: { raw: string | null; value: Cart } = { raw: null, value: EMPTY };

function read(): Cart {
  let raw: string | null = null;
  try {
    raw = window.localStorage.getItem(KEY);
  } catch {
    raw = null;
  }
  if (raw === cached.raw) return cached.value;
  let value: Cart = EMPTY;
  try {
    const parsed = raw ? (JSON.parse(raw) as Cart) : EMPTY;
    value = Array.isArray(parsed) ? parsed.filter((s) => s && Array.isArray(s.lines)) : EMPTY;
  } catch {
    value = EMPTY;
  }
  cached = { raw, value };
  return value;
}

function write(cart: Cart): void {
  const clean = cart
    .map((s) => ({ ...s, lines: s.lines.filter((l) => l.quantity > 0) }))
    .filter((s) => s.lines.length > 0);
  try {
    if (clean.length) window.localStorage.setItem(KEY, JSON.stringify(clean));
    else window.localStorage.removeItem(KEY);
  } catch {
    // Storage off: the basket lives as long as nothing reads it back.
  }
  window.dispatchEvent(new Event(EVENT));
}

function subscribe(onChange: () => void): () => void {
  const onStorage = (e: StorageEvent) => {
    if (e.key === KEY) onChange();
  };
  window.addEventListener(EVENT, onChange);
  window.addEventListener('storage', onStorage);
  return () => {
    window.removeEventListener(EVENT, onChange);
    window.removeEventListener('storage', onStorage);
  };
}

export function useCart(): Cart {
  return useSyncExternalStore(subscribe, read, () => EMPTY);
}

export function cartCount(cart: Cart): number {
  return cart.reduce((n, s) => n + s.lines.reduce((m, l) => m + l.quantity, 0), 0);
}

export function shopTotal(shop: CartShop): number | null {
  let total = 0;
  for (const l of shop.lines) {
    if (l.price === null) return null;
    total += l.price * l.quantity;
  }
  return total;
}

export function addToCart(
  shop: Omit<CartShop, 'lines'>,
  line: Omit<CartLine, 'quantity'>,
  quantity = 1,
): void {
  const cart = read().map((s) => ({ ...s, lines: [...s.lines] }));
  let bucket = cart.find((s) => s.vendorId === shop.vendorId);
  if (!bucket) {
    bucket = { ...shop, lines: [] };
    cart.push(bucket);
  }
  const existing = bucket.lines.find((l) => l.productId === line.productId);
  if (existing) existing.quantity = Math.min(99, existing.quantity + quantity);
  else bucket.lines.push({ ...line, quantity: Math.min(99, quantity) });
  write(cart);
}

export function setQuantity(vendorId: number, productId: number, quantity: number): void {
  write(
    read().map((s) =>
      s.vendorId !== vendorId
        ? s
        : {
            ...s,
            lines: s.lines.map((l) =>
              l.productId === productId ? { ...l, quantity: Math.max(0, Math.min(99, quantity)) } : l,
            ),
          },
    ),
  );
}

export function clearShop(vendorId: number): void {
  write(read().filter((s) => s.vendorId !== vendorId));
}

/** What is already in the basket for one product — for the button's label. */
export function quantityOf(cart: Cart, productId: number): number {
  for (const s of cart) {
    const l = s.lines.find((x) => x.productId === productId);
    if (l) return l.quantity;
  }
  return 0;
}
