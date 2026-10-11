import { allProducts, shopHrefs } from '@/lib/catalog';
import { productHref } from '@/lib/format';

/**
 * Every shop's and product's page, by id — written once at build time as a
 * static file.
 *
 * Notifications name a shop or a product by id only, and the static export
 * only has pages at slugged addresses. The notifications page reads this map
 * to send a tap to the real page rather than to a 404.
 */
export const dynamic = 'force-static';

export async function GET() {
  const [shops, products] = await Promise.all([shopHrefs(), allProducts()]);
  const vendors: Record<string, string> = {};
  for (const [id, href] of shops) vendors[id] = href;
  const productLinks: Record<string, string> = {};
  for (const p of products) productLinks[p.id] = productHref(p);
  return Response.json({ vendors, products: productLinks });
}
