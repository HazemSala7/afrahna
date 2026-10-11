import type { Metadata } from 'next';

import { Aurora, Bokeh, Petals, Rings, Sparkles } from '@/components/decor';
import { Magnetic, Reveal, Stagger } from '@/components/motion';

export const metadata: Metadata = {
  title: 'حمّل التطبيق',
  description:
    'تطبيق أفراحنا: دليل المحلات، دعوات إلكترونية، منسّق المناسبة، قائمة المهام،'
    + ' عروض حصرية ونقاط تتحوّل إلى مكافآت — على أندرويد وآيفون.',
};

const FEATURES = [
  { t: 'دعوات إلكترونية', d: 'صمّم دعوتك، شاركها برابط، وتابع الردود أولاً بأول.', e: '💌' },
  { t: 'منسّق المناسبة', d: 'خطّط تفاصيل يومك خطوة بخطوة مع قائمة مهام جاهزة.', e: '🗓️' },
  { t: 'عروض حصرية', d: 'خصومات من المحلات تصلك أول ما تُنشر.', e: '🎁' },
  { t: 'نقاط ومكافآت', d: 'اجمع النقاط من تفاعلك ودعوة أصدقائك واستبدلها بمكافآت.', e: '⭐' },
];

export default function AppPage() {
  return (
    <div className="grain relative overflow-hidden">
      <Aurora />
      <Bokeh count={12} rise="-760px" />
      <Sparkles count={12} />
      <Petals count={8} />

      <div className="container-site relative py-14">
        <div className="grid gap-10 lg:grid-cols-2 lg:items-center">
          <div>
            <Reveal kind="pop">
              <span className="chip backdrop-blur-sm">
                <Rings className="h-4 w-6" />
                أندرويد وآيفون
              </span>
            </Reveal>

            <Reveal delay={90}>
              <h1 className="mt-5 text-3xl font-black leading-tight text-ink sm:text-5xl">
                كل مناسبتك <span className="foil">في جيبك</span>
              </h1>
            </Reveal>

            <Reveal delay={160}>
              <p className="mt-4 max-w-lg text-[15px] leading-relaxed text-ink-muted">
                حمّل تطبيق أفراحنا وتصفّح مئات المحلات، صمّم دعوتك، وخطّط فرحك من
                مكان واحد.
              </p>
            </Reveal>

            <Reveal delay={230}>
              <div className="mt-7 flex flex-wrap gap-3">
                {/* Store links land here once the listings are live. */}
                <Magnetic>
                  <a href="https://play.google.com/store" className="btn-primary">
                    Google Play
                  </a>
                </Magnetic>
                <Magnetic>
                  <a href="https://apps.apple.com" className="btn-ghost">
                    App Store
                  </a>
                </Magnetic>
              </div>
            </Reveal>
          </div>

          <Stagger as="ul" className="grid gap-4 sm:grid-cols-2">
            {FEATURES.map((f) => (
              <li key={f.t} className="card card-hover shine group p-5">
                <span
                  className="grid h-11 w-11 place-items-center rounded-xl bg-brand-light/70 text-xl
                             transition-transform duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)]
                             group-hover:-rotate-6 group-hover:scale-110"
                  aria-hidden
                >
                  {f.e}
                </span>
                <h2 className="mt-3 font-black text-ink transition-colors group-hover:text-brand-dark">
                  {f.t}
                </h2>
                <p className="mt-1 text-sm leading-relaxed text-ink-muted">{f.d}</p>
                <span
                  className="mt-3 block h-[3px] w-0 rounded-full bg-gradient-to-l from-brand-accent
                             to-brand-dark transition-[width] duration-500 ease-out group-hover:w-12"
                  aria-hidden
                />
              </li>
            ))}
          </Stagger>
        </div>
      </div>
    </div>
  );
}
