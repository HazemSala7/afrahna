import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import PageHero from '@/components/PageHero';
import VendorCard from '@/components/VendorCard';
import { Stagger } from '@/components/motion';
import { Empty } from '@/components/ui';
import { allCategories, allVendors } from '@/lib/catalog';
import { idFromSlug, name, slugify } from '@/lib/format';

type Params = { params: { slug: string } };

/**
 * A category is its own page rather than a query string: real HTML, its own
 * title, and something a search engine can rank for "قاعات أفراح".
 */
export async function generateStaticParams() {
  const categories = await allCategories();
  return categories.map((c) => ({
    slug: `${c.slug || slugify(name(c))}-${c.id}`,
  }));
}

async function load(slug: string) {
  const id = idFromSlug(slug);
  if (!id) return null;
  return (await allCategories()).find((c) => c.id === id) ?? null;
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const category = await load(params.slug);
  if (!category) return { title: 'التصنيف غير موجود' };
  const title = name(category);
  return {
    title,
    description: `محلات وخدمات ${title} في فلسطين — تصفّح، قارن، وتواصل مباشرة عبر أفراحنا.`,
  };
}

export default async function CategoryPage({ params }: Params) {
  const category = await load(params.slug);
  if (!category) notFound();

  const [all, categories] = await Promise.all([allVendors(), allCategories()]);
  // A parent category shows everything underneath it too, not an empty page.
  const ids = new Set<number>([category.id]);
  for (const c of categories) if (c.parent_id === category.id) ids.add(c.id);
  const matching = all.filter((v) => v.category_id && ids.has(v.category_id));
  // Capped: the page shows the first 48 and says how many there are.
  const vendors = matching.slice(0, 48);

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="تصنيف"
        title={name(category)}
        subtitle={
          matching.length > 0
            ? `${matching.length.toLocaleString('ar-EG')} محل في هذا التصنيف — قارن وتواصل مباشرة`
            : 'لا توجد محلات في هذا التصنيف بعد'
        }
      />

      <div>
        {vendors.length === 0 ? (
          <Empty title="لا توجد محلات هنا بعد" hint="جرّب تصنيفاً آخر من الصفحة الرئيسية." />
        ) : (
          <Stagger className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 min-[1800px]:grid-cols-6">
            {vendors.map((v, i) => (
              <VendorCard key={v.id} vendor={v} eager={i < 4} />
            ))}
          </Stagger>
        )}
      </div>
    </div>
  );
}
