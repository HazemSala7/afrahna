import type { Metadata } from 'next';

import ReelsFeed from '@/components/ReelsFeed';
import { paged } from '@/lib/api';
import { shopHrefs } from '@/lib/catalog';
import { REELS_PAGE_SIZE, type Reel, toReel } from '@/lib/reels';
import type { Post } from '@/lib/types';

export const metadata: Metadata = {
  title: 'ريلز',
  description: 'أحدث فيديوهات وأعمال محلات الأفراح على أفراحنا — شاهدها وحدة ورا الثانية.',
};

/**
 * Reels, the way the app shows them: one video per screen, swiped upward, each
 * playing on its own the moment it arrives.
 *
 * The first page is fetched at build time and baked into the HTML, so the feed
 * opens on a poster straight away instead of a spinner. The browser carries on
 * from page two by itself (see `reelsPageUrl` for why that never reorders what
 * is already on screen).
 *
 * The build also has to supply every shop's real address. A reel embeds its
 * shop without a slug, and a static export only has pages at the slugged URLs —
 * a link made from the reel alone would land on a page that was never built.
 */
export default async function ReelsPage() {
  const [first, shops] = await Promise.all([
    paged<Post>('posts', { type: 'reel', per_page: REELS_PAGE_SIZE, page: 1 }),
    shopHrefs(),
  ]);

  const reels = first.data.map(toReel).filter((r): r is Reel => r !== null);
  const hrefs = Object.fromEntries(shops);

  return (
    <>
      <h1 className="sr-only">ريلز أفراحنا</h1>
      <ReelsFeed initial={reels} hasMore={first.current_page < first.last_page} hrefs={hrefs} />
    </>
  );
}
