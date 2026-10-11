import { paged } from './api';
import { vendorHref } from './format';
import type {
  Category, City, Highlight, InvitationTemplate, Post, Product, Review,
  Service, Story, TaskTemplate, Vendor,
} from './types';

/**
 * The whole catalogue, fetched once per build and held in memory.
 *
 * The obvious way to build a shop page is to ask the API for that shop's
 * products, services and reviews. With five hundred shops that is two thousand
 * requests against an endpoint that allows two hundred and forty a minute — the
 * first build did exactly that, collected a wall of 429s, and quietly shipped
 * pages whose "Products" section was empty because the request behind it had
 * been refused. A page that renders nothing looks the same as a shop with no
 * products, which is the worst kind of bug: silent and plausible.
 *
 * So: pull each collection whole, index it by `vendor_id`, and let every page
 * read from the map. Ten requests for the entire site, and a section is empty
 * only when it is genuinely empty.
 */

const PER_PAGE = 200;

/** Guard against a runaway paginator on a collection that keeps growing. */
const MAX_PAGES = 25;

/** Memoised per build — the promise, so parallel callers share one fetch. */
const cache = new Map<string, Promise<unknown>>();

function once<T>(key: string, load: () => Promise<T>): Promise<T> {
  const hit = cache.get(key);
  if (hit) return hit as Promise<T>;
  const p = load();
  cache.set(key, p);
  return p;
}

/** Walks a paginated endpoint to the end, one page at a time. */
async function collect<T>(
  path: string,
  query: Record<string, string | number> = {},
): Promise<T[]> {
  const out: T[] = [];
  for (let page = 1; page <= MAX_PAGES; page++) {
    const res = await paged<T>(path, { ...query, per_page: PER_PAGE, page });
    out.push(...res.data);
    if (res.data.length < PER_PAGE || page >= (res.last_page || 1)) break;
  }
  return out;
}

export const allVendors = () => once('vendors', () => collect<Vendor>('vendors'));
export const allProducts = () => once('products', () => collect<Product>('products'));
export const allServices = () => once('services', () => collect<Service>('services'));
export const allReviews = () => once('reviews', () => collect<Review>('reviews'));
export const allCategories = () =>
  once('categories', () => collect<Category>('categories'));
export const allCities = () => once('cities', () => collect<City>('cities'));
export const allPosts = () => once('posts', () => collect<Post>('posts'));
export const allStories = () => once('stories', () => collect<Story>('stories'));
export const allHighlights = () =>
  once('highlights', () => collect<Highlight>('highlights'));
export const allTemplates = () =>
  once('templates', () => collect<InvitationTemplate>('invitation-templates'));
export const allTaskTemplates = () =>
  once('task-templates', () => collect<TaskTemplate>('task-templates'));

/** Groups any vendor-owned collection by the shop it belongs to. */
function byVendor<T extends { vendor_id?: number | null }>(
  rows: T[],
): Map<number, T[]> {
  const map = new Map<number, T[]>();
  for (const r of rows) {
    const id = r.vendor_id;
    if (typeof id !== 'number') continue;
    const bucket = map.get(id);
    if (bucket) bucket.push(r);
    else map.set(id, [r]);
  }
  return map;
}

export const productsByVendor = () =>
  once('products:by-vendor', async () => byVendor(await allProducts()));
export const servicesByVendor = () =>
  once('services:by-vendor', async () => byVendor(await allServices()));
export const reviewsByVendor = () =>
  once('reviews:by-vendor', async () => byVendor(await allReviews()));
export const postsByVendor = () =>
  once('posts:by-vendor', async () => byVendor(await allPosts()));
export const storiesByVendor = () =>
  once('stories:by-vendor', async () => byVendor(await allStories()));
export const highlightsByVendor = () =>
  once('highlights:by-vendor', async () => byVendor(await allHighlights()));

/** One post by id, out of the single posts fetch. */
export async function postById(id: number): Promise<Post | null> {
  const map = await once('posts:by-id', async () => {
    const m = new Map<number, Post>();
    for (const p of await allPosts()) m.set(p.id, p);
    return m;
  });
  return map.get(id) ?? null;
}

/** One product by id, likewise. */
export async function productById(id: number): Promise<Product | null> {
  const map = await once('products:by-id', async () => {
    const m = new Map<number, Product>();
    for (const p of await allProducts()) m.set(p.id, p);
    return m;
  });
  return map.get(id) ?? null;
}

/** One shop by id, out of the single vendor fetch. */
export async function vendorById(id: number): Promise<Vendor | null> {
  const map = await once('vendors:by-id', async () => {
    const m = new Map<number, Vendor>();
    for (const v of await allVendors()) m.set(v.id, v);
    return m;
  });
  return map.get(id) ?? null;
}

/**
 * Every shop's real address, by id.
 *
 * Posts, reels, stories, offers and products embed their shop *without its
 * slug*, and a static export only has shop pages at the slugged URLs. Calling
 * `vendorHref` on one of those embedded shops makes up an address the build
 * never made — which the live site answers with a 404. Anything that knows a
 * shop only by id resolves it here instead.
 */
export const shopHrefs = () =>
  once('vendors:hrefs', async () => {
    const m = new Map<number, string>();
    for (const v of await allVendors()) m.set(v.id, vendorHref(v));
    return m;
  });

/**
 * A link-maker for shops known only by id: the shop's page, or `fallback`
 * when the shop is not in the catalogue (gone, or not yet built) — a list the
 * reader can use rather than a 404.
 */
export async function shopLinker() {
  const map = await shopHrefs();
  return (shop: { id: number } | null | undefined, fallback = '/vendors'): string =>
    (shop ? map.get(shop.id) : undefined) ?? fallback;
}
