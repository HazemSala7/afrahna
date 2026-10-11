import type { Metadata } from 'next';
import Link from 'next/link';

import PageHero from '@/components/PageHero';
import { Stagger } from '@/components/motion';
import { Empty, Img } from '@/components/ui';
import { list } from '@/lib/api';
import { shopLinker } from '@/lib/catalog';
import { discountLabel, excerpt, name } from '@/lib/format';
import type { Promotion } from '@/lib/types';

export const metadata: Metadata = {
  title: 'العروض',
  description: 'أحدث عروض وخصومات محلات الأفراح على أفراحنا.',
};

export default async function OffersPage() {
  const [offers, shopHref] = await Promise.all([
    list<Promotion>('promotions', { per_page: 60 }),
    shopLinker(),
  ]);

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="لفترة محدودة"
        title="العروض"
        subtitle="خصومات وعروض حصرية من محلات أفراحنا"
      />

      <div>
        {offers.length === 0 ? (
          <Empty
            title="لا توجد عروض فعّالة الآن"
            hint="تابعنا — تُضاف العروض الجديدة أولاً بأول."
          />
        ) : (
          <Stagger className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
            {offers.map((o, i) => (
              <Link
                key={o.id}
                href={shopHref(o.vendor)}
                className="card card-hover overflow-hidden"
              >
                <Img src={o.image} alt={o.title_ar ?? 'عرض'} ratio="aspect-[16/10]" eager={i < 3} />
                <div className="p-5">
                  <div className="flex items-start justify-between gap-2">
                    <h2 className="line-clamp-1 font-black text-ink">
                      {o.title_ar ?? 'عرض خاص'}
                    </h2>
                    {discountLabel(o.discount_type, o.discount_value) && (
                      <span className="chip shrink-0 !bg-sale/10 !text-sale">
                        {discountLabel(o.discount_type, o.discount_value)}
                      </span>
                    )}
                  </div>
                  {o.vendor && (
                    <p className="mt-1 text-xs text-ink-muted">{name(o.vendor)}</p>
                  )}
                  {o.description_ar && (
                    <p className="mt-2 line-clamp-2 text-sm text-ink-muted">
                      {excerpt(o.description_ar)}
                    </p>
                  )}
                </div>
              </Link>
            ))}
          </Stagger>
        )}
      </div>
    </div>
  );
}
