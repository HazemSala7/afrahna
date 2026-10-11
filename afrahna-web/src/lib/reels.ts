import { API_BASE } from './api';
import type { Post } from './types';

/**
 * A reel, reduced to what the feed draws.
 *
 * One shape for both halves of the feed — the first page baked into the HTML
 * at build time, and every page after it fetched by the browser — so the
 * component never has to know which half a reel came from.
 *
 * It lives in a plain module rather than beside the component on purpose: a
 * server page cannot call a function exported from a 'use client' file.
 */
export interface Reel {
  id: number;
  video: string;
  poster: string | null;
  caption: string;
  likes: number;
  comments: number;
  views: number;
  vendor: { id: number; name: string; logo: string | null } | null;
}

/** Reels per request — the app's page size, so both ask the API the same way. */
export const REELS_PAGE_SIZE = 10;

/** A post as a playable reel, or null when there is nothing to play. */
export function toReel(p: Post): Reel | null {
  if (p.is_published === false) return null;
  // Still being transcoded: the file is not there yet.
  if (p.video_status && p.video_status !== 'done') return null;
  if (!p.media_url) return null;

  const title = (p.title ?? '').trim();
  const body = (p.body ?? '').trim();
  const v = p.vendor;

  return {
    id: p.id,
    video: p.media_url,
    poster: p.thumbnail || p.images?.[0] || null,
    // The app's rule: both when they say different things, else whichever exists.
    caption: title && body && title !== body ? `${title}\n${body}` : title || body,
    likes: p.likes_count ?? 0,
    comments: p.comments_count ?? 0,
    views: p.views_count ?? 0,
    vendor: v
      ? { id: v.id, name: (v.name_ar || v.name_en || '').trim() || 'معلن', logo: v.logo || null }
      : null,
  };
}

/**
 * One page of the feed.
 *
 * Page one is the same for every visitor whatever the seed — the API only
 * shuffles from page two — which is what lets the build bake page one into the
 * HTML and the browser carry on from page two with a seed of its own.
 */
export function reelsPageUrl(page: number, seed: number): string {
  return `${API_BASE}/posts?type=reel&per_page=${REELS_PAGE_SIZE}&page=${page}&seed=${seed}`;
}
