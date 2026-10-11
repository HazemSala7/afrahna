import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import PageHero from '@/components/PageHero';
import VendorCard from '@/components/VendorCard';
import { Stagger } from '@/components/motion';
import { Empty } from '@/components/ui';
import { allCities, allVendors } from '@/lib/catalog';
import { idFromSlug, name, slugify } from '@/lib/format';

type Params = { params: { slug: string } };

export async function generateStaticParams() {
  const cities = await allCities();
  return cities.map((c) => ({ slug: `${c.slug || slugify(name(c))}-${c.id}` }));
}

async function load(slug: string) {
  const id = idFromSlug(slug);
  if (!id) return null;
  return (await allCities()).find((c) => c.id === id) ?? null;
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const city = await load(params.slug);
  if (!city) return { title: 'المدينة غير موجودة' };
  const title = name(city);
  return {
    title: `خدمات الأفراح في ${title}`,
    description: `قاعات، تصوير، أزياء، تجميل وضيافة في ${title} — كل المحلات في مكان واحد.`,
  };
}

export default async function CityPage({ params }: Params) {
  const city = await load(params.slug);
  if (!city) notFound();

  const matching = (await allVendors()).filter((v) => v.city_id === city.id);
  const vendors = matching.slice(0, 48);

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="مدينة"
        title={`خدمات الأفراح في ${name(city)}`}
        subtitle={`${matching.length.toLocaleString('ar-EG')} محل وخدمة — كلها في مدينتك`}
      />

      <div>
        {vendors.length === 0 ? (
          <Empty title="لا توجد محلات في هذه المدينة بعد" />
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
