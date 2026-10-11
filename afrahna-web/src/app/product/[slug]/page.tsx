import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import AddToCart from '@/components/commerce/AddToCart';
import { Reveal } from '@/components/motion';
import { Badge, Img, SectionHeader } from '@/components/ui';
import { allProducts, productById, productsByVendor, shopLinker } from '@/lib/catalog';
import {
  excerpt, idFromSlug, name, num, price, productHref, whatsappHref,
} from '@/lib/format';
import type { Product } from '@/lib/types';

type Params = { params: { slug: string } };

export async function generateStaticParams() {
  const products = await allProducts();
  return products.map((p) => ({ slug: productHref(p).replace('/product/', '') }));
}

async function load(slug: string) {
  const id = idFromSlug(slug);
  if (!id) return null;
  return productById(id);
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const product = await load(params.slug);
  if (!product) return { title: 'المنتج غير موجود' };
  const title = name(product);
  return {
    title,
    description:
      excerpt(product.description_ar, 155) ||
      `${title} من ${name(product.vendor)} — اطلبه عبر أفراحنا.`,
    openGraph: { title, images: product.image || undefined },
  };
}

export default async function ProductPage({ params }: Params) {
  const product = await load(params.slug);
  if (!product) notFound();

  const byVendor = await productsByVendor();
  // A product carries its shop without the shop's slug; resolve the real page.
  const shopHref = await shopLinker();
  const more = (product.vendor_id ? (byVendor.get(product.vendor_id) ?? []) : [])
    .filter((p) => p.id !== product.id)
    .slice(0, 6);

  const full = num(product.price);
  const sale = num(product.discount_price);
  const off = full && sale && sale < full
    ? Math.round(((full - sale) / full) * 100)
    : null;
  const wa = whatsappHref(product.vendor?.whatsapp || product.vendor?.phone);
  const gallery = [product.image, ...(product.images ?? [])].filter(Boolean) as string[];

  return (
    <div className="container-site py-10">
      {/* Google reads this as a product listing with a price. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            '@context': 'https://schema.org',
            '@type': 'Product',
            name: name(product),
            image: product.image ?? undefined,
            description: product.description_ar ?? undefined,
            brand: product.vendor ? { '@type': 'Brand', name: name(product.vendor) } : undefined,
            offers: (sale ?? full)
              ? {
                  '@type': 'Offer',
                  price: sale ?? full,
                  priceCurrency: 'ILS',
                  availability:
                    product.is_available === false
                      ? 'https://schema.org/OutOfStock'
                      : 'https://schema.org/InStock',
                }
              : undefined,
          }),
        }}
      />

      <div className="grid gap-10 lg:grid-cols-2 lg:items-start">
        <Reveal kind="zoom">
          <div className="card overflow-hidden">
            <Img src={product.image} alt={name(product)} eager ratio="aspect-square" />
          </div>
          {gallery.length > 1 && (
            <div className="mt-3 grid grid-cols-4 gap-3">
              {gallery.slice(0, 8).map((src, i) => (
                <Img key={i} src={src} alt="" ratio="aspect-square" className="rounded-xl" />
              ))}
            </div>
          )}
        </Reveal>

        <Reveal delay={90}>
          <div className="lg:sticky lg:top-24">
            {product.vendor && (
              <Link
                href={shopHref(product.vendor)}
                className="text-sm font-bold text-brand-dark hover:underline"
              >
                {name(product.vendor)}
              </Link>
            )}
            <h1 className="mt-2 text-3xl font-black text-ink">{name(product)}</h1>

            <div className="mt-4 flex flex-wrap items-center gap-3">
              {sale ? (
                <>
                  <span className="text-3xl font-black text-sale">{price(sale)}</span>
                  <span className="text-lg text-ink-muted line-through">{price(full)}</span>
                  {off && <Badge tone="sale">خصم {off}%</Badge>}
                </>
              ) : (
                price(full) && (
                  <span className="text-3xl font-black text-brand-dark">{price(full)}</span>
                )
              )}
              {product.is_available === false && (
                <span className="chip !bg-ink-muted/10 !text-ink-muted">غير متوفّر حالياً</span>
              )}
            </div>

            {product.description_ar && (
              <p className="mt-5 whitespace-pre-line text-[15px] leading-relaxed text-ink-muted">
                {product.description_ar}
              </p>
            )}

            {/* The order goes to the shop as an invoice, as it does from the
                app: no payment on the site, the shop confirms and delivers,
                and the customer follows each step from «طلباتي». */}
            {product.vendor_id && product.is_available !== false && (
              <div className="mt-8">
                <AddToCart
                  product={{
                    id: product.id,
                    name: name(product),
                    image: product.image,
                    price: sale ?? full,
                  }}
                  shop={{
                    id: product.vendor_id,
                    name: name(product.vendor) || 'المحل',
                    href: product.vendor ? shopHref(product.vendor) : null,
                  }}
                />
                <p className="mt-2 text-xs text-ink-muted">
                  الدفع عند الاستلام — ويصلك إشعار عند تأكيد المحل وبكل خطوة بعدها.
                </p>
              </div>
            )}

            <div className="mt-6 flex flex-wrap gap-3">
              {wa && (
                <a
                  href={`${wa}?text=${encodeURIComponent(`مرحباً، أنا مهتم بـ${name(product)} من أفراحنا`)}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn bg-[#25D366] text-white"
                >
                  استفسر عبر واتساب
                </a>
              )}
              {product.vendor?.phone && (
                <a href={`tel:${product.vendor.phone}`} className="btn-ghost">
                  اتصال بالمحل
                </a>
              )}
              {product.vendor && (
                <Link href={shopHref(product.vendor)} className="btn-ghost">
                  كل منتجات المحل
                </Link>
              )}
            </div>
          </div>
        </Reveal>
      </div>

      {more.length > 0 && (
        <section className="mt-20">
          <SectionHeader
            kicker="من نفس المحل"
            title="منتجات أخرى"
            href={shopHref(product.vendor, '/products')}
          />
          <div className="rail">
            {more.map((p) => (
              <Link key={p.id} href={productHref(p)} className="card card-hover w-[200px] overflow-hidden">
                <Img src={p.image} alt={name(p)} ratio="aspect-square" />
                <div className="p-3">
                  <h3 className="line-clamp-1 text-sm font-black text-ink">{name(p)}</h3>
                  <p className="mt-1 text-sm font-black text-brand-dark">
                    {price(p.discount_price) ?? price(p.price)}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
