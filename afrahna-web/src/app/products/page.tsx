import type { Metadata } from 'next';
import Link from 'next/link';

import PageHero from '@/components/PageHero';
import { Stagger } from '@/components/motion';
import { Empty, Img } from '@/components/ui';
import { allProducts } from '@/lib/catalog';
import { name, price, productHref } from '@/lib/format';

export const metadata: Metadata = {
  title: 'المتجر',
  description:
    'منتجات الأفراح والمناسبات من كل المحلات — توزيعات، هدايا، ديكور وأكثر.',
};

export default async function ProductsPage() {
  const products = (await allProducts()).filter((p) => p.is_available !== false);

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="اشترِ مباشرة"
        title="المتجر"
        subtitle={`${products.length.toLocaleString('ar-EG')} منتج من محلات أفراحنا — بأسعارها وعروضها`}
      />

      <div>
        {products.length === 0 ? (
          <Empty title="لا توجد منتجات معروضة الآن" />
        ) : (
          <Stagger className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 2xl:grid-cols-5 min-[1800px]:grid-cols-6">
            {products.map((p, i) => {
              const card = (
                <>
                  <Img src={p.image} alt={name(p)} ratio="aspect-square" eager={i < 4} />
                  <div className="p-4">
                    <h2 className="line-clamp-1 font-black text-ink">{name(p)}</h2>
                    {p.vendor && (
                      <p className="mt-0.5 line-clamp-1 text-xs text-ink-muted">
                        {name(p.vendor)}
                      </p>
                    )}
                    <div className="mt-2 flex items-baseline gap-2">
                      {price(p.discount_price) ? (
                        <>
                          <span className="font-black text-sale">{price(p.discount_price)}</span>
                          <span className="text-xs text-ink-muted line-through">{price(p.price)}</span>
                        </>
                      ) : (
                        price(p.price) && (
                          <span className="font-black text-brand-dark">{price(p.price)}</span>
                        )
                      )}
                    </div>
                  </div>
                </>
              );
              return (
                <Link key={p.id} href={productHref(p)} className="card card-hover overflow-hidden">
                  {card}
                </Link>
              );
            })}
          </Stagger>
        )}
      </div>
    </div>
  );
}
