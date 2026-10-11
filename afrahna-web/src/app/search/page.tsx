import type { Metadata } from 'next';

import SearchClient from '@/components/SearchClient';
import { allCategories, allCities, allVendors } from '@/lib/catalog';
import { name, vendorHref } from '@/lib/format';

export const metadata: Metadata = {
  title: 'بحث',
  description: 'ابحث عن محل أو خدمة أو مدينة في دليل أفراحنا.',
  robots: { index: false, follow: true },
};

/**
 * Search over an index built at build time.
 *
 * The site is static, so there is no server to query — but five hundred shops
 * reduced to name, category and city is a payload of a few tens of kilobytes,
 * which the browser can filter instantly and offline. Nothing to wait for and
 * no request per keystroke.
 */
export default async function SearchPage() {
  const [vendors, categories, cities] = await Promise.all([
    allVendors(),
    allCategories(),
    allCities(),
  ]);

  const catById = new Map(categories.map((c) => [c.id, name(c)]));
  const cityById = new Map(cities.map((c) => [c.id, name(c)]));

  const index = vendors.map((v) => ({
    i: v.id,
    n: name(v),
    c: v.category_id ? (catById.get(v.category_id) ?? '') : '',
    t: v.city_id ? (cityById.get(v.city_id) ?? '') : '',
    l: v.logo || v.cover_image || '',
    h: vendorHref(v),
  }));

  return <SearchClient index={index} />;
}
