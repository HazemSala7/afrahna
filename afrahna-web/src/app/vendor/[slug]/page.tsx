import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import ContactBar from '@/components/ContactBar';
import BookService from '@/components/commerce/BookService';
import VendorCard from '@/components/VendorCard';
import { Badge, Img, SectionHeader, Stars } from '@/components/ui';
import { Sparkles } from '@/components/decor';
import { Reveal, Stagger } from '@/components/motion';
import { SITE_URL } from '@/lib/api';
import {
  allVendors, highlightsByVendor, postsByVendor, productsByVendor,
  reviewsByVendor, servicesByVendor, storiesByVendor, vendorById,
} from '@/lib/catalog';
import {
  excerpt, idFromSlug, name, postHref, price, productHref, rating, vendorHref,
} from '@/lib/format';
import type { Product, Review, Service, Vendor } from '@/lib/types';

type Params = { params: { slug: string } };

/**
 * A shop's page — the reason most people will arrive from a search engine.
 *
 * Every one of the ~500 shops is pre-rendered into its own HTML file, so these
 * pages open instantly and are indexable without JavaScript. The URL carries
 * the shop's name for the reader and its id for the API, which resolves shops
 * by id only.
 */
export async function generateStaticParams() {
  const vendors = await allVendors();
  return vendors.map((v) => ({
    slug: vendorHref(v).replace('/vendor/', ''),
  }));
}

async function load(slug: string) {
  const id = idFromSlug(slug);
  if (!id) return null;
  return vendorById(id);
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const vendor = await load(params.slug);
  if (!vendor) return { title: 'المحل غير موجود' };

  const title = name(vendor);
  const where = [name(vendor.category), name(vendor.city)]
    .filter(Boolean)
    .join(' · ');
  const description =
    excerpt(vendor.description_ar, 155) ||
    `${title}${where ? ` — ${where}` : ''}. تواصل، تصفّح الأعمال والأسعار على أفراحنا.`;

  return {
    title,
    description,
    alternates: { canonical: vendorHref(vendor) },
    openGraph: {
      title,
      description,
      images: vendor.cover_image || vendor.logo || undefined,
      type: 'profile',
    },
  };
}

export default async function VendorPage({ params }: Params) {
  const vendor = await load(params.slug);
  if (!vendor) notFound();

  // All four come out of the catalogue loaded once for the whole build — this
  // page makes no request of its own.
  const [productMap, serviceMap, reviewMap, postMap, storyMap, highlightMap, vendors] =
    await Promise.all([
      productsByVendor(),
      servicesByVendor(),
      reviewsByVendor(),
      postsByVendor(),
      storiesByVendor(),
      highlightsByVendor(),
      allVendors(),
    ]);

  const products = (productMap.get(vendor.id) ?? []).slice(0, 12);
  const services = (serviceMap.get(vendor.id) ?? []).slice(0, 12);
  const reviews = (reviewMap.get(vendor.id) ?? [])
    .filter((r) => r.comment)
    .slice(0, 6);

  const posts = (postMap.get(vendor.id) ?? []).filter((p) => p.is_published !== false);
  const gallery = posts.filter((p) => p.type !== 'reel').slice(0, 12);
  const reels = posts.filter((p) => p.type === 'reel').slice(0, 8);
  const stories = (storyMap.get(vendor.id) ?? [])
    .filter((st) => st.is_active !== false && st.is_approved !== false)
    .slice(0, 10);
  const highlights = (highlightMap.get(vendor.id) ?? [])
    .filter((h) => h.is_active !== false)
    .slice(0, 8);

  const bookable = (serviceMap.get(vendor.id) ?? [])
    .filter((s) => s.is_active !== false)
    .map((s) => ({ id: s.id, name: name(s), price: price(s.discount_price) ?? price(s.price) }));

  const stars = rating(vendor.rating);
  const others = vendors
    .filter((v) => v.id !== vendor.id && v.category_id === vendor.category_id)
    .slice(0, 4);

  return (
    <>
      {/* Search engines read this; people read everything below it. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(businessSchema(vendor)) }}
      />

      <header className="relative">
        <div className="relative overflow-hidden">
          <Img
            src={vendor.cover_image}
            alt=""
            eager
            ratio="aspect-[16/6] min-h-[180px]"
            className="w-full"
          />
          {/* The cover drifts very slowly, so the top of the page is
              never a still photograph — and a shop with no cover still
              gets a band that is doing something. */}
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-cream via-cream/20 to-transparent" aria-hidden />
        </div>
        <div className="container-site relative -mt-16 pb-2">
          <div className="card grain relative flex flex-col gap-4 overflow-hidden p-5 sm:flex-row sm:items-center">
            <Sparkles count={7} />
            {vendor.logo && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={vendor.logo}
                alt=""
                width={88}
                height={88}
                fetchPriority="high"
                decoding="async"
                className="relative shrink-0 rounded-2xl border border-brand-light object-cover"
                style={{ height: 88, width: 88 }}
              />
            )}
            <div className="relative min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="text-2xl font-black text-ink sm:text-3xl">
                  {name(vendor)}
                </h1>
                {!!vendor.is_verified && <Badge tone="verified">موثّق ✓</Badge>}
                {!!vendor.is_vip && <Badge>VIP ⭐</Badge>}
              </div>
              <p className="mt-1 text-sm text-ink-muted">
                {[name(vendor.category), name(vendor.city), vendor.address]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
              <div className="mt-2 flex flex-wrap items-center gap-4 text-xs text-ink-muted">
                {stars && <Stars value={stars} count={vendor.reviews_count} />}
                {typeof vendor.views_count === 'number' && vendor.views_count > 0 && (
                  <span>{vendor.views_count.toLocaleString('ar-EG')} مشاهدة</span>
                )}
                {price(vendor.min_price) && (
                  <span>تبدأ الأسعار من {price(vendor.min_price)}</span>
                )}
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="container-site mt-6">
        {/* Booking goes through Afrahna, so the request is on record, the shop
            is notified at once, and the customer can follow its answer. */}
        {(bookable.length > 0 || !vendor.is_store) && (
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <BookService shop={{ id: vendor.id, name: name(vendor) }} services={bookable} />
            <p className="text-xs text-ink-muted">يصل طلبك للمحل فوراً، وتتابع ردّه من «مناسباتي».</p>
          </div>
        )}
        <ContactBar vendor={vendor} />
      </div>

      {vendor.description_ar && (
        <section className="container-site mt-10">
          <Reveal>
            <SectionHeader title="عن المحل" />
          </Reveal>
          <p className="max-w-3xl whitespace-pre-line text-[15px] leading-relaxed text-ink-muted">
            {vendor.description_ar}
          </p>
        </section>
      )}

      {services.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader title="الخدمات" emoji="🎀" />
          </Reveal>
          <Stagger className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 2xl:grid-cols-6">
            {services.map((s) => (
              <article key={s.id} className="card card-hover shine group overflow-hidden">
                <Img src={s.image} alt={name(s)} />
                <div className="p-4">
                  <h3 className="line-clamp-1 font-black text-ink">{name(s)}</h3>
                  {s.description_ar && (
                    <p className="mt-1 line-clamp-2 text-sm text-ink-muted">
                      {excerpt(s.description_ar, 80)}
                    </p>
                  )}
                  {price(s.price) && (
                    <p className="mt-2 font-black text-brand-dark">{price(s.price)}</p>
                  )}
                  <BookService
                    shop={{ id: vendor.id, name: name(vendor) }}
                    services={bookable}
                    preselect={s.id}
                    variant="card"
                  />
                </div>
              </article>
            ))}
          </Stagger>
        </section>
      )}

      {products.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader title="المنتجات" emoji="🛍️" />
          </Reveal>
          <Stagger className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 2xl:grid-cols-6">
            {products.map((p) => (
              <Link key={p.id} href={productHref(p)} className="card card-hover shine group overflow-hidden">
                <Img src={p.image} alt={name(p)} ratio="aspect-square" />
                <div className="p-4">
                  <h3 className="line-clamp-1 font-black text-ink">{name(p)}</h3>
                  <div className="mt-2 flex items-baseline gap-2">
                    {price(p.discount_price) ? (
                      <>
                        <span className="font-black text-sale">
                          {price(p.discount_price)}
                        </span>
                        <span className="text-xs text-ink-muted line-through">
                          {price(p.price)}
                        </span>
                      </>
                    ) : (
                      price(p.price) && (
                        <span className="font-black text-brand-dark">
                          {price(p.price)}
                        </span>
                      )
                    )}
                  </div>
                </div>
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      {highlights.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader kicker="مختارات" title="أبرز الأعمال" emoji="📌" />
          </Reveal>
          <Stagger className="rail">
            {highlights.map((h) => (
              <figure key={h.id} className="w-[120px] text-center">
                <div className="overflow-hidden rounded-full border-2 border-brand-light p-1">
                  <Img
                    src={h.cover_image}
                    alt={h.title ?? ''}
                    ratio="aspect-square"
                    className="rounded-full"
                  />
                </div>
                <figcaption className="mt-2 line-clamp-1 text-xs font-bold text-ink">
                  {h.title}
                </figcaption>
              </figure>
            ))}
          </Stagger>
        </section>
      )}

      {stories.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader kicker="اليوم" title="الستوري" emoji="⚡" />
          </Reveal>
          <Stagger className="rail">
            {stories.map((st) => (
              <figure key={st.id} className="w-[150px]">
                <Img
                  src={st.image}
                  alt={st.caption_ar ?? ''}
                  ratio="aspect-[9/16]"
                  className="rounded-2xl"
                />
                {st.caption_ar && (
                  <figcaption className="mt-2 line-clamp-2 text-xs text-ink-muted">
                    {st.caption_ar}
                  </figcaption>
                )}
              </figure>
            ))}
          </Stagger>
        </section>
      )}

      {reels.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader kicker="بالفيديو" title="الريلز" emoji="🎬" href="/reels" />
          </Reveal>
          <Stagger className="rail">
            {reels.map((r) => (
              <Link
                key={r.id}
                href={`/reels?id=${r.id}`}
                className="card card-hover shine group w-[170px] overflow-hidden"
              >
                <div className="relative">
                  <Img src={r.thumbnail || r.images?.[0]} alt={r.title ?? ''} ratio="aspect-[9/16]" />
                  <span className="absolute inset-0 grid place-items-center">
                    <span className="grid h-10 w-10 place-items-center rounded-full bg-black/45 text-white backdrop-blur-sm transition-transform group-hover:scale-110">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                        <path d="M8 5l11 7-11 7V5Z" />
                      </svg>
                    </span>
                  </span>
                </div>
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      {gallery.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader kicker="من أعمالنا" title="المعرض" emoji="🖼️" />
          </Reveal>
          <Stagger className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6">
            {gallery.map((g) => (
              <div key={g.id} className="card card-hover shine group overflow-hidden">
                <Img src={g.images?.[0] || g.thumbnail} alt={g.title ?? ''} ratio="aspect-square" />
                {g.title && (
                  <p className="line-clamp-1 p-3 text-xs font-bold text-ink">{g.title}</p>
                )}
              </div>
            ))}
          </Stagger>
        </section>
      )}

      {reviews.length > 0 && (
        <section className="container-site mt-12">
          <Reveal>
            <SectionHeader title="آراء الزبائن" emoji="💬" />
          </Reveal>
          <Stagger className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
            {reviews.map((r) => (
              <blockquote key={r.id} className="card card-hover p-5">
                {typeof r.rating === 'number' && (
                  <Stars value={r.rating.toFixed(1)} />
                )}
                {r.comment && (
                  <p className="mt-2 text-sm leading-relaxed text-ink-muted">
                    {r.comment}
                  </p>
                )}
                <footer className="mt-3 text-xs font-bold text-ink">
                  {r.user?.name || r.guest_name || 'زائر'}
                </footer>
              </blockquote>
            ))}
          </Stagger>
        </section>
      )}

      {others.length > 0 && (
        <section className="container-site mt-14">
          <Reveal>
            <SectionHeader title="محلات مشابهة" emoji="✨" href="/vendors" />
          </Reveal>
          <Stagger className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {others.map((v) => (
              <VendorCard key={v.id} vendor={v} />
            ))}
          </Stagger>
        </section>
      )}

      <div className="container-site mt-14">
        <Link href="/vendors" className="text-sm font-bold text-brand-dark hover:underline">
          ← عودة إلى كل المحلات
        </Link>
      </div>
    </>
  );
}

function businessSchema(v: Vendor) {
  const stars = rating(v.rating);
  return {
    '@context': 'https://schema.org',
    '@type': 'LocalBusiness',
    name: name(v),
    description: v.description_ar ?? undefined,
    image: v.cover_image || v.logo || undefined,
    telephone: v.phone ?? undefined,
    url: `${SITE_URL}${vendorHref(v)}`,
    address: v.address
      ? { '@type': 'PostalAddress', streetAddress: v.address, addressLocality: name(v.city) }
      : undefined,
    aggregateRating:
      stars && v.reviews_count
        ? {
            '@type': 'AggregateRating',
            ratingValue: stars,
            reviewCount: v.reviews_count,
          }
        : undefined,
  };
}
