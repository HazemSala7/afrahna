import type { Bilingual, Vendor } from './types';

/** The Arabic name, falling back to the English one rather than to nothing. */
export function name(r: Bilingual | null | undefined): string {
  if (!r) return '';
  return (r.name_ar || r.name_en || '').trim();
}

/** A number the API may send as a string, or not at all. */
export function num(v: number | string | null | undefined): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

/** «١٬٢٣٤» — grouped, Arabic digits, no decimals. */
export function count(v: number | null | undefined): string {
  return typeof v === 'number' ? v.toLocaleString('ar-EG') : '—';
}

/** «٤٫٩» to one place, or null when a shop has no rating yet. */
export function rating(v: number | string | null | undefined): string | null {
  const n = num(v);
  if (n === null || n <= 0) return null;
  return n.toFixed(1);
}

export function price(v: number | string | null | undefined): string | null {
  const n = num(v);
  if (n === null || n <= 0) return null;
  return `${n.toLocaleString('ar-EG', { maximumFractionDigits: 0 })} ₪`;
}

/**
 * The canonical path for a shop.
 *
 * The API resolves `vendors/{id}` by id only — the slug 404s — so the id is
 * what the URL has to carry. The name rides in front of it for the reader and
 * for search engines; the route parses the id off the end.
 */
export function vendorHref(v: Pick<Vendor, 'id' | 'slug'> & Bilingual): string {
  const s = (v.slug || slugify(name(v))).replace(/^-+|-+$/g, '');
  return s ? `/vendor/${s}-${v.id}` : `/vendor/${v.id}`;
}

/** The id at the end of a `name-123` segment. */
export function idFromSlug(segment: string): number | null {
  const m = /(\d+)$/.exec(segment);
  return m ? Number(m[1]) : null;
}

export function slugify(s: string): string {
  return s
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
}

/** A phone number as WhatsApp wants it: digits, with the country code. */
export function whatsappHref(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let d = raw.replace(/\D/g, '');
  if (!d) return null;
  // Local Palestinian numbers are stored as 05XXXXXXXX; WhatsApp needs 970.
  if (d.startsWith('00')) d = d.slice(2);
  else if (d.startsWith('0')) d = `970${d.slice(1)}`;
  return `https://wa.me/${d}`;
}

/** What a promotion takes off, said the way the shop set it. */
export function discountLabel(
  type: string | null | undefined,
  value: number | string | null | undefined,
): string | null {
  const n = num(value);
  if (n === null || n <= 0) return null;
  return type === 'amount' ? `خصم ${n} ₪` : `خصم ${n}%`;
}

/** Trims a description to a card-sized sentence without cutting a word. */
export function excerpt(s: string | null | undefined, max = 110): string {
  const t = (s ?? '').replace(/\s+/g, ' ').trim();
  if (t.length <= max) return t;
  return `${t.slice(0, t.lastIndexOf(' ', max) || max)}…`;
}

/** `/post/{title}-{id}` — reels and posts share one route. */
export function postHref(p: { id: number; title?: string | null; type?: string | null }): string {
  const s = slugify(p.title ?? (p.type === 'reel' ? 'reel' : 'post'));
  return `/post/${s ? `${s}-` : ''}${p.id}`;
}

/** `/product/{name}-{id}`. */
export function productHref(p: { id: number } & Bilingual): string {
  const s = slugify(name(p));
  return `/product/${s ? `${s}-` : ''}${p.id}`;
}
