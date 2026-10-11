/**
 * The one place that talks to the Laravel API.
 *
 * Every page here is rendered at build time, so most of these calls happen on
 * a build machine rather than in a browser: a failure must not take the whole
 * site down with it. `safe()` therefore turns a dead endpoint into an empty
 * section — a home page missing its offers row still ships, and still sells.
 */

export const API_BASE =
  process.env.NEXT_PUBLIC_API_URL ?? 'https://afrahna.co/admin/api/v1';

/**
 * Where this build of the site will live.
 *
 * Separate from [API_BASE] on purpose: the API and the dashboard stay on
 * afrahna.co, while the public site is being put on afrahna.ps. Canonical
 * links, the sitemap and the social cards must name the domain the reader is
 * actually on, or every page will point search engines at a different site.
 */
export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL ?? 'https://afrahna.ps'
).replace(/\/$/, '');

/** Laravel's paginator envelope. */
export interface Page<T> {
  data: T[];
  total: number;
  current_page: number;
  last_page: number;
}

type Query = Record<string, string | number | boolean | undefined>;

function url(path: string, query?: Query): string {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(query ?? {})) {
    if (v !== undefined && v !== '') qs.set(k, String(v));
  }
  const q = qs.toString();
  return `${API_BASE}/${path}${q ? `?${q}` : ''}`;
}

export async function api<T>(path: string, query?: Query): Promise<T> {
  const target = url(path, query);

  // The public API allows 240 requests a minute per IP. A build that walks the
  // whole catalogue stays well inside that, but a retry costs far less than a
  // page shipped with a section silently missing — so a 429 waits and asks
  // again rather than giving up.
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(target, {
      headers: { Accept: 'application/json' },
      // Build-time fetches are cached for the length of the build, so twenty
      // pages asking for the same category list cost one request.
      next: { revalidate: 300 },
    });

    if (res.ok) return res.json() as Promise<T>;

    if (res.status === 429 && attempt < 4) {
      const retryAfter = Number(res.headers.get('retry-after'));
      const waitMs = Number.isFinite(retryAfter) && retryAfter > 0
        ? retryAfter * 1000
        : 2000 * 2 ** attempt;
      await new Promise((r) => setTimeout(r, waitMs));
      continue;
    }

    throw new Error(`${path} → ${res.status}`);
  }
}

/** A list endpoint, unwrapped from the paginator and never throwing. */
export async function list<T>(path: string, query?: Query): Promise<T[]> {
  try {
    const body = await api<Page<T> | T[]>(path, query);
    return Array.isArray(body) ? body : (body.data ?? []);
  } catch (e) {
    console.warn(`[api] ${path} unavailable:`, (e as Error).message);
    return [];
  }
}

/** A list endpoint where the total matters (directory pagination). */
export async function paged<T>(
  path: string,
  query?: Query,
): Promise<Page<T>> {
  try {
    const body = await api<Page<T> | T[]>(path, query);
    if (Array.isArray(body)) {
      return { data: body, total: body.length, current_page: 1, last_page: 1 };
    }
    return body;
  } catch (e) {
    console.warn(`[api] ${path} unavailable:`, (e as Error).message);
    return { data: [], total: 0, current_page: 1, last_page: 1 };
  }
}

/** A single record, or null when it is gone. */
export async function one<T>(path: string, query?: Query): Promise<T | null> {
  try {
    return await api<T>(path, query);
  } catch {
    return null;
  }
}
