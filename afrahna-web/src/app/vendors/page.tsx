import type { Metadata } from 'next';

import PageHero from '@/components/PageHero';
import VendorCard from '@/components/VendorCard';
import { Stagger } from '@/components/motion';
import { Empty } from '@/components/ui';
import { paged } from '@/lib/api';
import { allCategories, allCities } from '@/lib/catalog';
import { name, slugify } from '@/lib/format';
import type { Category, City, Vendor } from '@/lib/types';

import Link from 'next/link';

export const metadata: Metadata = {
  title: 'كل المحلات',
  description:
    'تصفّح مئات محلات وخدمات الأفراح في فلسطين — قاعات، تصوير، فساتين، تجميل،'
    + ' ضيافة وحلويات — مرتّبة حسب التصنيف والمدينة.',
};

/**
 * The directory.
 *
 * Filtering happens by navigating to a category or city page rather than by
 * running a query in the browser: each combination is then its own URL with
 * its own HTML, which is both faster to open and something a search engine can
 * actually index. The client-side filter would have been easier and worse.
 */
export default async function VendorsPage() {
  const [page, categories, cities] = await Promise.all([
    paged<Vendor>('vendors', { per_page: 48 }),
    allCategories(),
    allCities(),
  ]);

  const roots = categories.filter((c) => !c.parent_id);

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="الدليل"
        title="كل المحلات"
        subtitle={
          page.total > 0
            ? `${page.total.toLocaleString('ar-EG')} محل وخدمة في انتظارك — قاعات، تصوير، أزياء، تجميل، ضيافة وأكثر`
            : 'دليل محلات وخدمات الأفراح'
        }
      />

      {roots.length > 0 && (
        <nav aria-label="التصنيفات" className="mb-6">
          <div className="rail">
            {roots.map((c) => (
              <Link
                key={c.id}
                href={`/category/${c.slug || slugify(name(c))}-${c.id}`}
                className="chip whitespace-nowrap hover:bg-brand-light"
              >
                {name(c)}
              </Link>
            ))}
          </div>
        </nav>
      )}

      {cities.length > 0 && (
        <nav aria-label="المدن" className="mb-8">
          <div className="rail">
            {cities.map((c) => (
              <Link
                key={c.id}
                href={`/city/${c.slug || slugify(name(c))}-${c.id}`}
                className="chip whitespace-nowrap !bg-cream-surface !text-ink-muted
                           hover:!bg-brand-light hover:!text-brand-dark"
              >
                {name(c)}
              </Link>
            ))}
          </div>
        </nav>
      )}

      {page.data.length === 0 ? (
        <Empty
          title="لا توجد محلات لعرضها الآن"
          hint="جرّب لاحقاً، أو تصفّح التصنيفات بالأعلى."
        />
      ) : (
        <Stagger className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 min-[1800px]:grid-cols-6">
          {page.data.map((v, i) => (
            <VendorCard key={v.id} vendor={v} eager={i < 4} />
          ))}
        </Stagger>
      )}
    </div>
  );
}
