import type { MetadataRoute } from 'next';

import { SITE_URL } from '@/lib/api';
import { allCategories, allCities, allVendors } from '@/lib/catalog';
import { name, slugify, vendorHref } from '@/lib/format';

export const dynamic = 'force-static';

const SITE = SITE_URL;

/**
 * Every page the site has, so the ~500 shop pages are found rather than waited
 * for. Written at build time from the same catalogue the pages come from, so
 * the two can never drift apart.
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [vendors, categories, cities] = await Promise.all([
    allVendors(),
    allCategories(),
    allCities(),
  ]);

  const staticPages = [
    '', '/vendors', '/categories', '/products', '/offers', '/reels',
    '/about', '/contact', '/privacy', '/advertise', '/app',
  ].map((p) => ({
    url: `${SITE}${p}`,
    changeFrequency: 'weekly' as const,
    priority: p === '' ? 1 : 0.7,
  }));

  return [
    ...staticPages,
    ...categories.map((c) => ({
      url: `${SITE}/category/${c.slug || slugify(name(c))}-${c.id}`,
      changeFrequency: 'weekly' as const,
      priority: 0.6,
    })),
    ...cities.map((c) => ({
      url: `${SITE}/city/${c.slug || slugify(name(c))}-${c.id}`,
      changeFrequency: 'weekly' as const,
      priority: 0.5,
    })),
    ...vendors.map((v) => ({
      url: `${SITE}${vendorHref(v)}`,
      changeFrequency: 'monthly' as const,
      priority: 0.8,
    })),
  ];
}
