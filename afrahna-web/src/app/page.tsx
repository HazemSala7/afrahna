import Link from 'next/link';

import CategoryRail from '@/components/CategoryRail';
import FeaturedVendors from '@/components/FeaturedVendors';
import Hero from '@/components/Hero';
import VendorCard from '@/components/VendorCard';
import { Confetti, Flourish, Garland, GoldDivider, Sparkles } from '@/components/decor';
import { CountUp, Magnetic, Reveal, Stagger } from '@/components/motion';
import { SectionHeader } from '@/components/ui';
import { list, one } from '@/lib/api';
import {
  allCategories, allCities, allPosts, allProducts, allStories, allTemplates, shopLinker,
} from '@/lib/catalog';
import {
  count, discountLabel, name, price, productHref, slugify, vendorHref,
} from '@/lib/format';
import type { Slide } from '@/components/HeroSlider';
import type { Category, Promotion, SiteStats, Slider, Vendor } from '@/lib/types';

import { Img } from '@/components/ui';

/** The three steps, for the reader who has never planned one of these before. */
const STEPS = [
  {
    n: '١',
    title: 'اختار التصنيف',
    body: 'قاعة، مصوّر، فستان، كوافير، ضيافة — كل شي مرتّب بمكانه.',
    emoji: '🔎',
  },
  {
    n: '٢',
    title: 'قارن وشوف الشغل',
    body: 'صور وريلز وتقييمات حقيقية من عرسان قبلك، وأسعار وعروض.',
    emoji: '⭐',
  },
  {
    n: '٣',
    title: 'تواصل واحجز',
    body: 'واتساب أو اتصال مباشر مع المحل — بلا وسيط وبلا عمولة.',
    emoji: '💬',
  },
];

/**
 * The home page, assembled at build time.
 *
 * Everything below is fetched once when the site is built and baked into HTML,
 * so opening afrahna.co costs one request and paints without waiting on the
 * API at all. The lists are fetched in parallel — sequential awaits would make
 * the build eight round-trips deep for no reason.
 */
export default async function HomePage() {
  const [
    featured, newest, topRated, categories, offers, stats, posts, stories,
    templates, products, cities, vips, adminSlides,
  ] =
    await Promise.all([
      list<Vendor>('vendors', { per_page: 12, is_featured: 1 }),
      list<Vendor>('vendors', { per_page: 8, sort: 'newest' }),
      list<Vendor>('vendors', { per_page: 8, sort: 'rating' }),
      allCategories(),
      list<Promotion>('promotions', { per_page: 6 }),
      one<SiteStats>('stats'),
      allPosts(),
      allStories(),
      allTemplates(),
      allProducts(),
      allCities(),
      list<Vendor>('vendors', { vip: 1, per_page: 60 }),
      list<Slider>('sliders', { limit: 60 }),
    ]);

  const published = posts.filter((p) => p.is_published !== false);
  const latest = published.filter((p) => p.type !== 'reel').slice(0, 8);
  const reels = published.filter((p) => p.type === 'reel').slice(0, 8);
  // One circle per shop, not one per story: a shop that posted ten stories was
  // filling the whole rail with itself and hiding the other nine shops.
  const liveStories = (() => {
    const seen = new Set<number>();
    const out = [];
    for (const st of stories) {
      if (st.is_active === false || st.is_approved === false) continue;
      const vid = st.vendor_id;
      if (typeof vid !== 'number' || seen.has(vid)) continue;
      seen.add(vid);
      out.push(st);
      if (out.length === 12) break;
    }
    return out;
  })();
  const cards = templates.filter((t) => t.is_active !== false).slice(0, 6);
  // Shown in the order the API returns them, which is newest first.
  const shop = products.filter((pr) => pr.is_available !== false).slice(0, 10);

  // The hero carousel, built exactly the way the app builds it: the slides an
  // admin created, plus every VIP shop as a slide of its own. There are no
  // admin slides at the moment, so in practice this is the VIP list — which is
  // what the app shows too.
  const slides: Slide[] = [
    ...adminSlides
      .filter((sl) => sl.image)
      .map((sl) => ({
        id: sl.id,
        image: sl.image as string,
        title: sl.title_ar ?? 'أفراحنا',
        subtitle: sl.subtitle_ar ?? undefined,
        badge: sl.badge_ar ?? undefined,
        href: sl.link || '/vendors',
      })),
    ...vips
      // Cover photos only: a shop whose picture is a square logo cannot fill
      // a banner, and used to be shown letterboxed against a blurred copy of
      // itself.
      .filter((v) => v.cover_image)
      .map((v) => ({
        // Negative, so an admin slide and a shop can never share an id.
        id: -v.id,
        image: v.cover_image as string,
        title: name(v),
        subtitle: name(v.category) || undefined,
        badge: 'VIP ⭐',
        href: vendorHref(v),
      })),
  ].slice(0, 12);

  // The nine top-level categories; the rest are their children and belong on
  // the category pages, not in a rail that has to stay glanceable.
  const roots = categories.filter((c) => !c.parent_id);

  // Stories, offers and posts carry their shop without its slug; this turns
  // the id into the page the build actually made.
  const shopHref = await shopLinker();

  return (
    <>
      {/* The page's one heading. Visually hidden — the first screen is the
          banners — but a search engine and a screen reader still need to
          be told what this page is. */}
      <h1 className="sr-only">أفراحنا — كل ما يلزم مناسبتك في مكان واحد</h1>

      <Hero slides={slides} />

      {/* The shops that pay to be seen, first thing past the hero. */}
      <FeaturedVendors vendors={featured} />

      <section className="container-site mt-14">
        <Reveal>
          <SectionHeader
            kicker="ابدأ من هنا"
            title="ابحث حسب التصنيف"
            href="/categories"
          />
        </Reveal>
        {/* The rail brings its own tiles in one after another. */}
        <CategoryRail categories={roots.length ? roots : categories} />
      </section>

      {liveStories.length > 0 && (
        <section className="container-site mt-16">
          <Reveal>
            <SectionHeader
              kicker="جديد اليوم"
              title="الستوري"
              emoji="⚡"
              href="/stories"
            />
          </Reveal>
          <Stagger className="rail">
            {liveStories.map((st) => (
              <Link
                key={st.id}
                href={shopHref(st.vendor, '/stories')}
                className="group w-[104px] text-center"
              >
                {/* The gold ring turns while the circle is pointed at, which is
                    the web's version of "this story is unread". */}
                <span className="relative block rounded-full p-[3px]">
                  <span
                    className="absolute inset-0 rounded-full bg-gradient-to-br from-brand-accent via-sale/70 to-brand-dark
                               transition-transform duration-500 group-hover:scale-105"
                    aria-hidden
                  />
                  <span className="relative block rounded-full bg-cream p-[3px]">
                    <Img
                      src={st.vendor?.logo || st.image}
                      alt=""
                      ratio="aspect-square"
                      className="rounded-full"
                    />
                  </span>
                </span>
                <span className="mt-2 block truncate text-xs font-bold text-ink transition-colors group-hover:text-brand-dark">
                  {st.vendor ? name(st.vendor) : 'ستوري'}
                </span>
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      <div className="container-site mt-20">
        <Reveal kind="fade">
          <GoldDivider />
        </Reveal>
      </div>

      {/* ---------------------------------------------------- how it works */}

      <section className="container-site mt-16">
        <Reveal>
          <SectionHeader kicker="بأبسط شكل" title="كيف بتشتغل أفراحنا؟" emoji="✨" />
        </Reveal>
        <Stagger className="grid gap-5 sm:grid-cols-3">
          {STEPS.map((s) => (
            <div
              key={s.n}
              className="card card-hover shine group relative overflow-hidden p-6 pt-8"
            >
              {/* The step number, huge and pale behind the text — a page that
                  looks designed rather than listed. */}
              <span
                className="pointer-events-none absolute -left-2 -top-6 select-none text-[7rem]
                           font-black leading-none text-brand-light/60 transition-transform
                           duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:-translate-y-1
                           group-hover:text-brand-light"
                aria-hidden
              >
                {s.n}
              </span>
              <span
                className="relative grid h-14 w-14 place-items-center rounded-2xl bg-gradient-to-br
                           from-brand-accent to-brand-dark text-2xl shadow-lift transition-transform
                           duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:-rotate-6
                           group-hover:scale-110"
                aria-hidden
              >
                {s.emoji}
              </span>
              <h3 className="relative mt-4 text-lg font-black text-ink">{s.title}</h3>
              <p className="relative mt-1.5 text-sm leading-relaxed text-ink-muted">
                {s.body}
              </p>
              <span
                className="relative mt-4 block h-[3px] w-8 rounded-full bg-gradient-to-l from-brand-accent
                           to-brand-dark transition-[width] duration-500 ease-out group-hover:w-20"
                aria-hidden
              />
            </div>
          ))}
        </Stagger>
      </section>

      {shop.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader
              kicker="اشترِ مباشرة"
              title="المتجر"
              emoji="🛍️"
              href="/products"
            />
          </Reveal>
          <Stagger className="rail">
            {shop.map((pr, i) => (
              <Link
                key={pr.id}
                href={productHref(pr)}
                className="card card-hover shine group w-[210px] overflow-hidden"
              >
                <div className="relative">
                  <Img src={pr.image} alt={name(pr)} ratio="aspect-square" eager={i < 4} />
                  {price(pr.discount_price) && (
                    <span className="absolute right-3 top-3">
                      <span className="inline-flex items-center rounded-full bg-gradient-to-br from-[#E0654A] to-sale px-2.5 py-1 text-[11px] font-black text-white shadow-[0_4px_12px_rgba(193,69,43,0.35)]">
                        تخفيض
                      </span>
                    </span>
                  )}
                </div>
                <div className="p-4">
                  <h3 className="line-clamp-1 text-sm font-black text-ink transition-colors group-hover:text-brand-dark">
                    {name(pr)}
                  </h3>
                  {pr.vendor && (
                    <p className="mt-0.5 line-clamp-1 text-xs text-ink-muted">
                      {name(pr.vendor)}
                    </p>
                  )}
                  <div className="mt-2 flex items-baseline gap-2">
                    {price(pr.discount_price) ? (
                      <>
                        <span className="text-sm font-black text-sale">
                          {price(pr.discount_price)}
                        </span>
                        <span className="text-xs text-ink-muted line-through">
                          {price(pr.price)}
                        </span>
                      </>
                    ) : (
                      price(pr.price) && (
                        <span className="text-sm font-black text-brand-dark">
                          {price(pr.price)}
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

      {offers.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader
              kicker="لفترة محدودة"
              title="عروض اليوم"
              emoji="🔥"
              href="/offers"
            />
          </Reveal>
          <Stagger className="rail">
            {offers.map((o) => (
              <Link
                key={o.id}
                href={shopHref(o.vendor, '/offers')}
                className="card card-hover shine w-[280px] overflow-hidden"
              >
                <Img src={o.image} alt={o.title_ar ?? 'عرض'} ratio="aspect-[16/10]" />
                <div className="p-4">
                  <h3 className="line-clamp-1 font-black text-ink">
                    {o.title_ar ?? 'عرض خاص'}
                  </h3>
                  {o.vendor && (
                    <p className="mt-1 line-clamp-1 text-xs text-ink-muted">
                      {name(o.vendor)}
                    </p>
                  )}
                  {discountLabel(o.discount_type, o.discount_value) && (
                    <span className="chip mt-2 !bg-sale/10 !text-sale">
                      {discountLabel(o.discount_type, o.discount_value)}
                    </span>
                  )}
                </div>
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      {latest.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader kicker="من المحلات" title="آخر المنشورات" emoji="📝" />
          </Reveal>
          <Stagger className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4 2xl:grid-cols-6">
            {latest.slice(0, 6).map((p, i) => (
              <Link
                key={p.id}
                href={shopHref(p.vendor)}
                // The fifth and sixth only fill out a six-column row.
                className={`card card-hover shine group block overflow-hidden ${i >= 4 ? 'hidden 2xl:block' : ''}`}
              >
                <Img src={p.images?.[0] || p.thumbnail} alt={p.title ?? ''} ratio="aspect-[4/3]" />
                <div className="p-4">
                  {p.title && (
                    <h3 className="line-clamp-1 font-black text-ink transition-colors group-hover:text-brand-dark">
                      {p.title}
                    </h3>
                  )}
                  {p.vendor && (
                    <p className="mt-1 line-clamp-1 text-xs text-ink-muted">
                      {name(p.vendor)}
                    </p>
                  )}
                </div>
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      {newest.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader
              kicker="وجوه جديدة"
              title="انضم مؤخراً"
              emoji="🌱"
              href="/vendors"
            />
          </Reveal>
          <Stagger className="rail">
            {newest.slice(0, 8).map((v) => (
              <VendorCard key={v.id} vendor={v} className="w-[260px]" />
            ))}
          </Stagger>
        </section>
      )}

      {topRated.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader
              kicker="بشهادة الزبائن"
              title="الأعلى تقييماً"
              emoji="⭐"
              href="/vendors"
            />
          </Reveal>
          <Stagger className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4 2xl:grid-cols-6">
            {topRated.slice(0, 6).map((v, i) => (
              <VendorCard key={v.id} vendor={v} className={i >= 4 ? 'hidden 2xl:block' : ''} />
            ))}
          </Stagger>
        </section>
      )}

      {cities.length > 0 && (
        <section className="marquee edge-fade relative mt-20 overflow-hidden border-y border-brand-light/60 bg-cream-surface py-5">
          {/* Two identical halves scrolling as one strip: when the first has
              travelled its own width the second is exactly where it started,
              so the loop has no seam. Pauses on hover so a name can be read. */}
          <div className="marquee-track flex w-max gap-10">
            {[0, 1].map((half) => (
              <div key={half} className="flex shrink-0 gap-10" aria-hidden={half === 1}>
                {cities.map((c) => (
                  <Link
                    key={`${half}-${c.id}`}
                    href={`/city/${c.slug || slugify(name(c))}-${c.id}`}
                    className="group flex items-center gap-3 text-lg font-black text-ink-muted transition-colors hover:text-brand-dark"
                  >
                    <span
                      className="h-1.5 w-1.5 rounded-full bg-brand transition-transform duration-300 group-hover:scale-[2.2]"
                      aria-hidden
                    />
                    {name(c)}
                  </Link>
                ))}
              </div>
            ))}
          </div>
        </section>
      )}

      {cards.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader
              kicker="بلا مطابع"
              title="دعوات إلكترونية"
              emoji="💌"
              href="/invitations"
            />
          </Reveal>
          <Stagger className="grid grid-cols-2 gap-5 lg:grid-cols-4 2xl:grid-cols-6">
            {cards.map((t, i) => (
              <Link
                key={t.id}
                href="/invitations"
                className={`card card-hover shine group block overflow-hidden ${i >= 4 ? 'hidden 2xl:block' : ''}`}
              >
                <div className="relative">
                  <Img
                    src={t.preview_image || t.background_image}
                    alt={t.name ?? 'قالب دعوة'}
                    ratio="aspect-[3/4]"
                  />
                  {/* The card opening: a line of text rising over the artwork. */}
                  <span
                    className="pointer-events-none absolute inset-x-0 bottom-0 translate-y-full bg-gradient-to-t
                               from-black/75 to-transparent p-3 text-center text-[11px] font-black text-white
                               opacity-0 transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]
                               group-hover:translate-y-0 group-hover:opacity-100"
                    aria-hidden
                  >
                    جهّز دعوتك بدقائق
                  </span>
                </div>
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      {reels.length > 0 && (
        <section className="container-site mt-20">
          <Reveal>
            <SectionHeader kicker="شاهد" title="ريلز" emoji="🎬" href="/reels" />
          </Reveal>
          <Stagger className="rail">
            {reels.map((r) => (
              <Link
                key={r.id}
                // Opens the feed on this reel. (It used to link to the shop, built
                // from the reel's embedded shop — which has no slug, so the link
                // pointed at a page the static export never built.)
                href={`/reels?id=${r.id}`}
                className="card card-hover shine group w-[170px] overflow-hidden"
              >
                <div className="relative">
                  <Img src={r.thumbnail || r.images?.[0]} alt={r.title ?? ''} ratio="aspect-[9/16]" />
                  <span className="absolute inset-0 grid place-items-center">
                    {/* A ring pulses out of the play button while it is hovered,
                        the way a tapped control does in the app. */}
                    <span className="relative grid h-11 w-11 place-items-center">
                      <span
                        className="absolute inset-0 rounded-full bg-white/60 opacity-0 transition-opacity duration-300 group-hover:opacity-100"
                        style={{ animation: 'pulse-ring 1.8s ease-out infinite' }}
                        aria-hidden
                      />
                      <span className="relative grid h-11 w-11 place-items-center rounded-full bg-black/45 text-white backdrop-blur-sm transition-transform duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:scale-110">
                        <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                          <path d="M8 5l11 7-11 7V5Z" />
                        </svg>
                      </span>
                    </span>
                  </span>
                </div>
                {r.vendor && (
                  <p className="line-clamp-1 p-3 text-xs font-bold text-ink">
                    {name(r.vendor)}
                  </p>
                )}
              </Link>
            ))}
          </Stagger>
        </section>
      )}

      {/* ------------------------------------------------------- the bands */}

      <section className="container-site mt-24">
        <Reveal kind="zoom">
          <div className="grain relative overflow-hidden rounded-[2rem] border border-brand-light bg-cream-surface p-8 shadow-card sm:p-10">
            <Sparkles count={10} />
            <div
              className="pointer-events-none absolute -left-20 -top-20 h-56 w-56 rounded-full bg-brand-accent/25 blur-3xl"
              aria-hidden
            />
            <div className="relative flex flex-col items-start gap-6 sm:flex-row sm:items-center">
              <span className="float grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-brand-accent to-brand-dark text-white shadow-lift">
                <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                  <path d="M3 11l18-6-6 18-3-7-9-5Z" />
                </svg>
              </span>
              <div className="min-w-0 flex-1">
                <h2 className="text-2xl font-black text-ink">عندك محل أو خدمة؟</h2>
                <p className="mt-1 text-sm leading-relaxed text-ink-muted">
                  أعلن في أفراحنا ووصّل للآلاف من المقبلين على الزواج — صفحة
                  كاملة لأعمالك، منشورات وريلز وستوري، وظهور في الصفحة الرئيسية.
                </p>
              </div>
              <Magnetic className="shrink-0">
                <Link href="/advertise" className="btn-primary">
                  أعلن معنا
                </Link>
              </Magnetic>
            </div>
          </div>
        </Reveal>
      </section>

      <section className="container-site mt-24">
        <div className="grain sweep relative grid gap-8 overflow-hidden rounded-[2rem] bg-gradient-to-bl from-brand-dark via-brand to-brand-accent p-8 text-white shadow-lift sm:p-14 lg:grid-cols-[1.2fr_1fr] lg:items-center">
          {/* The one moment on the page that is openly a celebration. */}
          <Confetti count={18} drop="620px" />
          <Garland bulbs={13} />

          {/* A wash of light across the band, so it is not a flat rectangle. */}
          <div
            className="pointer-events-none absolute -left-24 -top-24 h-72 w-72 rounded-full bg-white/15 blur-3xl"
            aria-hidden
          />
          <div
            className="pointer-events-none absolute -bottom-28 -right-16 h-80 w-80 rounded-full bg-black/15 blur-3xl"
            aria-hidden
          />

          <Reveal kind="right" className="relative z-10">
            <h2 className="text-3xl font-black sm:text-4xl">
              خطّط فرحك <span className="foil-light">من جوالك</span>
            </h2>
            <p className="mt-3 max-w-lg text-sm leading-relaxed text-white/85">
              دعوات إلكترونية، منسّق المناسبة، قائمة المهام، عروض حصرية ونقاط
              تتحوّل إلى مكافآت — كلها في تطبيق أفراحنا.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Magnetic>
                <Link href="/app" className="btn bg-white text-brand-dark hover:bg-cream">
                  حمّل التطبيق
                </Link>
              </Magnetic>
              <Magnetic>
                <Link
                  href="/advertise"
                  className="btn border border-white/40 text-white hover:bg-white/10"
                >
                  أعلن معنا
                </Link>
              </Magnetic>
            </div>
          </Reveal>

          {stats && (
            <Stagger as="dl" className="relative z-10 grid grid-cols-2 gap-4">
              {[
                { k: 'vendors', label: 'محل وخدمة' },
                { k: 'users', label: 'مستخدم' },
                { k: 'cities', label: 'مدينة' },
                { k: 'services', label: 'خدمة' },
              ].map(({ k, label }) => (
                <div
                  key={k}
                  className="glass rounded-2xl p-5 text-center transition-transform duration-500
                             ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-1.5 hover:bg-white/20"
                >
                  <dt className="sr-only">{label}</dt>
                  <dd className="text-3xl font-black">
                    {typeof stats[k] === 'number' ? (
                      <CountUp to={stats[k] as number} />
                    ) : (
                      count(stats[k])
                    )}
                  </dd>
                  <p className="mt-1 text-xs text-white/75">{label}</p>
                </div>
              ))}
            </Stagger>
          )}
        </div>
      </section>

      <section className="container-site mt-16">
        <Reveal kind="zoom">
          <div className="grain relative overflow-hidden rounded-[2rem] border border-brand-light bg-gradient-to-l from-brand-light/70 to-cream-surface p-8 shadow-card sm:p-10">
            <Sparkles count={8} />
            <div className="relative flex flex-col items-start gap-6 sm:flex-row sm:items-center">
              <span className="float grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-white text-brand-dark shadow-card">
                <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                  <path d="M16 20v-1.5a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4V20" />
                  <circle cx="9" cy="7" r="3.2" />
                  <path d="M19 8v6M22 11h-6" />
                </svg>
              </span>
              <div className="min-w-0 flex-1">
                <h2 className="text-2xl font-black text-ink">ادعُ أصدقاءك</h2>
                <p className="mt-1 text-sm leading-relaxed text-ink-muted">
                  أرسل كودك إلى أصدقائك واجعلهم يستخدمونه عند إنشاء حسابهم في
                  التطبيق لتحصل على 3 نقاط فوراً — وكل 100 نقطة تساوي 50 شيكل.
                </p>
              </div>
              <Magnetic className="shrink-0">
                <Link href="/points" className="btn-ghost">
                  كيف تعمل النقاط؟
                </Link>
              </Magnetic>
            </div>
          </div>
        </Reveal>
      </section>

      <div className="container-site mt-20">
        <Reveal kind="fade">
          <GoldDivider />
        </Reveal>
        <Flourish className="mx-auto mt-6 w-44 opacity-50" />
      </div>
    </>
  );
}
