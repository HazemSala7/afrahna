import type { Metadata } from 'next';
import Link from 'next/link';

import PageHero from '@/components/PageHero';
import { Reveal } from '@/components/motion';
import { Empty, Img } from '@/components/ui';
import { allStories, shopLinker } from '@/lib/catalog';
import { name } from '@/lib/format';

export const metadata: Metadata = {
  title: 'الستوري',
  description: 'آخر ما نشرته محلات أفراحنا اليوم — عروض، أعمال، وجديد كل يوم.',
};

export default async function StoriesPage() {
  // Newest first, and interleaved by shop rather than grouped: ten stories
  // from one shop in a row pushes every other shop off the first screen.
  const shopHref = await shopLinker();
  const live = (await allStories()).filter(
    (s) => s.is_active !== false && s.is_approved !== false,
  );

  const byVendor = new Map<number | string, typeof live>();
  for (const s of live) {
    const key = s.vendor_id ?? 'none';
    const bucket = byVendor.get(key);
    if (bucket) bucket.push(s);
    else byVendor.set(key, [s]);
  }
  const stories: typeof live = [];
  for (let round = 0; stories.length < live.length; round++) {
    let added = false;
    for (const bucket of byVendor.values()) {
      if (bucket[round]) {
        stories.push(bucket[round]);
        added = true;
      }
    }
    if (!added) break;
  }

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="جديد اليوم"
        title="الستوري"
        subtitle="جديد المحلات، أولاً بأول"
      />

      <div>
        {stories.length === 0 ? (
          <Empty title="لا توجد ستوري منشورة الآن" />
        ) : (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5 2xl:grid-cols-6 min-[1800px]:grid-cols-8">
            {stories.map((s, i) => {
              const inner = (
                <>
                  <div className="relative">
                    <Img
                      src={s.image}
                      alt={s.caption_ar ?? ''}
                      ratio="aspect-[9/16]"
                      eager={i < 5}
                    />
                    <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />
                    {s.vendor && (
                      <div className="absolute inset-x-0 bottom-0 flex items-center gap-2 p-3">
                        {s.vendor.logo && (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={s.vendor.logo}
                            alt=""
                            width={28}
                            height={28}
                            loading="lazy"
                            className="h-7 w-7 rounded-full border border-white/70 object-cover"
                          />
                        )}
                        <span className="truncate text-xs font-bold text-white">
                          {name(s.vendor)}
                        </span>
                      </div>
                    )}
                  </div>
                  {s.caption_ar && (
                    <p className="line-clamp-2 p-3 text-xs text-ink-muted">
                      {s.caption_ar}
                    </p>
                  )}
                </>
              );

              return (
                <Reveal key={s.id} delay={(i % 5) * 70}>
                  {s.vendor ? (
                    <Link
                      href={shopHref(s.vendor, '/stories')}
                      className="card card-hover block overflow-hidden"
                    >
                      {inner}
                    </Link>
                  ) : (
                    <article className="card overflow-hidden">{inner}</article>
                  )}
                </Reveal>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
