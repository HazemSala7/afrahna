import Link from 'next/link';

import { Bokeh, Flourish, Garland, Rings } from './decor';
import { Reveal } from './motion';

const SECTIONS = [
  {
    title: 'تصفّح',
    links: [
      { href: '/vendors', label: 'كل المحلات' },
      { href: '/categories', label: 'التصنيفات' },
      { href: '/products', label: 'المتجر' },
      { href: '/offers', label: 'العروض' },
      { href: '/reels', label: 'ريلز' },
      { href: '/stories', label: 'الستوري' },
    ],
  },
  {
    title: 'أفراحنا',
    links: [
      { href: '/invitations', label: 'الدعوات الإلكترونية' },
      { href: '/planning', label: 'خطّطي فرحك' },
      { href: '/points', label: 'النقاط والمكافآت' },
      { href: '/about', label: 'من نحن' },
      { href: '/app', label: 'حمّل التطبيق' },
      { href: '/advertise', label: 'أعلن معنا' },
      { href: '/contact', label: 'تواصل معنا' },
      { href: '/privacy', label: 'سياسة الخصوصية' },
    ],
  },
];

/**
 * The foot of every page.
 *
 * Treated as a room rather than a sitemap: a string of lights along the top
 * edge, candlelight rising behind the columns, and every link growing its own
 * gold rule as it is pointed at. It is the last thing anyone sees, and on a
 * wedding site it should not be the one flat grey rectangle on the page.
 */
export default function Footer() {
  // `pb-24` on small screens: the floating bottom bar covers the last ~86px of
  // the page, and the copyright line was sitting underneath it.
  return (
    <footer className="relative mt-20 overflow-hidden border-t border-brand-light bg-cream-surface pb-24 md:pb-0">
      <Garland />
      <Bokeh count={10} rise="-560px" />

      <div className="container-site relative grid gap-10 py-16 sm:grid-cols-2 lg:grid-cols-4">
        <Reveal className="lg:col-span-2">
          <div className="group flex items-center gap-3">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/logo.png"
              alt=""
              width={48}
              height={48}
              className="h-12 w-12 rounded-xl object-cover transition-transform duration-500
                         ease-[cubic-bezier(0.34,1.56,0.64,1)] group-hover:-rotate-6 group-hover:scale-105"
            />
            <div>
              <div className="text-lg font-black text-brand-dark">أفراحنا</div>
              <div className="text-xs text-ink-muted">
                كل ما يلزم مناسبتك في مكان واحد
              </div>
            </div>
          </div>

          <p className="mt-4 max-w-md text-sm leading-relaxed text-ink-muted">
            دليل خدمات الأفراح والمناسبات في فلسطين — قاعات، تصوير، فساتين،
            تجميل، ضيافة وحلويات ودعوات إلكترونية، من مئات المحلات الموثوقة في
            مكان واحد.
          </p>

          <div className="mt-6 flex items-center gap-3">
            <Rings className="float h-7 w-10" />
            <span className="text-xs font-bold text-brand-dark">
              مئات المحلات · كل المدن · مكان واحد
            </span>
          </div>
        </Reveal>

        {SECTIONS.map((s, i) => (
          <Reveal key={s.title} delay={120 + i * 100}>
            <nav>
              <h2 className="mb-3 text-sm font-black text-ink">{s.title}</h2>
              <ul className="space-y-2">
                {s.links.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className="group inline-flex items-center gap-2 text-sm text-ink-muted
                                 transition-colors hover:text-brand-dark"
                    >
                      {/* A gold rule that grows out of nothing before the label
                          and pushes it along a little. */}
                      <span
                        className="h-px w-0 rounded-full bg-gradient-to-l from-brand-accent to-brand-dark
                                   transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]
                                   group-hover:w-4"
                        aria-hidden
                      />
                      <span className="transition-transform duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]">
                        {l.label}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          </Reveal>
        ))}
      </div>

      <div className="container-site relative pb-8">
        <Flourish className="mx-auto w-40 opacity-50" />
      </div>

      <div className="relative border-t border-brand-light/70">
        <div className="container-site flex flex-col items-center justify-between gap-2 py-5 text-xs text-ink-muted sm:flex-row">
          <span>© {new Date().getFullYear()} أفراحنا. جميع الحقوق محفوظة.</span>
          <span className="inline-flex items-center gap-1.5">
            صُنع بحبّ
            <span className="heartbeat inline-block text-sale" aria-hidden>
              ♥
            </span>
            في فلسطين
          </span>
        </div>
      </div>
    </footer>
  );
}
