import type { Metadata } from 'next';
import Link from 'next/link';

import CategoryIcon from '@/components/CategoryIcon';
import PageHero from '@/components/PageHero';
import { Stagger } from '@/components/motion';
import { allCategories } from '@/lib/catalog';
import { name, slugify } from '@/lib/format';

export const metadata: Metadata = {
  title: 'التصنيفات',
  description:
    'كل تصنيفات خدمات الأفراح على أفراحنا — قاعات، تصوير، أزياء، تجميل، ضيافة،'
    + ' هدايا وسيارات — مع أقسامها الفرعية.',
};

/** The whole tree on one page: roots as headings, children as links. */
export default async function CategoriesPage() {
  const all = await allCategories();
  const roots = all.filter((c) => !c.parent_id);

  return (
    <div className="container-site py-10">
      <PageHero
        kicker="كل شي بمكانه"
        title="التصنيفات"
        subtitle="اختر ما تحتاجه لمناسبتك — وكل تصنيف بأقسامه الفرعية"
      />

      <Stagger className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
        {roots.map((root) => {
          const children = all.filter((c) => c.parent_id === root.id);
          const href = `/category/${root.slug || slugify(name(root))}-${root.id}`;
          return (
            <section key={root.id} className="card card-hover shine group p-5">
              <Link href={href} className="flex items-center gap-3">
                <span className="grid h-12 w-12 place-items-center rounded-xl bg-brand-light/60 text-brand-dark">
                  <CategoryIcon icon={root.icon} title={name(root)} size={22} />
                </span>
                <h2 className="font-black text-ink">{name(root)}</h2>
              </Link>
              {children.length > 0 && (
                <ul className="mt-4 flex flex-wrap gap-2">
                  {children.map((c) => (
                    <li key={c.id}>
                      <Link
                        href={`/category/${c.slug || slugify(name(c))}-${c.id}`}
                        className="chip hover:bg-brand-light"
                      >
                        {name(c)}
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          );
        })}
      </Stagger>
    </div>
  );
}
