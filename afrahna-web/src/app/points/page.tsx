import type { Metadata } from 'next';
import Link from 'next/link';

import { Aurora, Bokeh, Flourish, Sparkles } from '@/components/decor';
import { Reveal } from '@/components/motion';
import { SectionHeader } from '@/components/ui';

export const metadata: Metadata = {
  title: 'النقاط والمكافآت',
  description:
    'اجمع نقاط أفراحنا من تفاعلك ودعوة أصدقائك، واصعد المستويات — كل مستوى'
    + ' يمنحك 50 شيكل عند بلوغ هدفه.',
};

/**
 * The rewards ladder, exactly as the app awards it.
 *
 * These figures are the programme's rules, not marketing copy: they match
 * `PointsRules` on the server, and if the ladder is ever retuned there this
 * page has to be retuned with it.
 */
const RUNGS = [
  { name: 'برونزي', goal: 100, rate: 5, from: '#E0A272', to: '#C17C48' },
  { name: 'فضي', goal: 200, rate: 7, from: '#E3E7EB', to: '#9AA5B1' },
  { name: 'ذهبي', goal: 400, rate: 10, from: '#F3D06A', to: '#D9A521' },
  { name: 'بلاتيني', goal: 800, rate: 15, from: '#BBD3EC', to: '#6C8EBF' },
];

const EARN = [
  { t: 'إنشاء حساب', d: 'هدية الانضمام', v: '5 نقاط' },
  { t: 'دعوة صديق', d: 'يسجّل بكودك', v: '3 نقاط' },
  { t: 'المواظبة اليومية', d: '30 يوماً متتالياً', v: '90 نقطة' },
  { t: 'الاشتراك السنوي', d: 'مرة واحدة', v: '10 نقاط' },
  { t: 'إعجاباتك وتعليقاتك', d: 'حتى 3 تفاعلات محتسبة يومياً', v: 'حسب مستواك' },
];

export default function PointsPage() {
  return (
    <>
      <section className="grain relative overflow-hidden border-b border-brand-light/60 bg-gradient-to-b from-cream-surface to-cream">
        <Aurora />
        <Sparkles count={12} />
        <Bokeh count={10} rise="-480px" />
        <div className="container-site relative py-16 text-center">
          <Reveal>
            <span className="chip">برنامج المكافآت</span>
            <h1 className="mt-4 text-4xl font-black leading-tight text-ink sm:text-5xl">
              تفاعلك يتحوّل إلى <span className="foil">مكافآت</span>
            </h1>
            <p className="mx-auto mt-5 max-w-2xl text-base leading-loose text-ink-muted">
              اجمع النقاط من استخدامك للتطبيق ومن دعوة أصدقائك. كلما بلغت هدف
              مستواك حصلت على <strong className="text-brand-dark">50 شيكل</strong>،
              وانتقلت إلى المستوى الذي يليه.
            </p>
            <Link href="/app" className="btn-primary mt-8">
              ابدأ من التطبيق
            </Link>
          </Reveal>
          <Flourish className="mx-auto mt-10 w-40 opacity-70" />
        </div>
      </section>

      <section className="container-site mt-16">
        <SectionHeader kicker="أربعة مستويات" title="سلّم المكافآت" emoji="🏅" />
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {RUNGS.map((r, i) => (
            <Reveal key={r.name} delay={i * 90}>
              <article className="card h-full p-6 text-center">
                <span
                  className="mx-auto grid h-16 w-16 place-items-center rounded-full text-white shadow-lift"
                  style={{ background: `linear-gradient(135deg, ${r.from}, ${r.to})` }}
                >
                  <svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                    <path d="M12 2l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4L7.5 15.8l.9-5L4.8 7.3l5-.7L12 2Z" />
                  </svg>
                </span>
                <h3 className="mt-4 text-lg font-black text-ink">
                  المستوى {i + 1} · {r.name}
                </h3>
                <p className="mt-2 text-sm text-ink-muted">
                  {r.goal} نقطة ← <strong className="text-brand-dark">50 شيكل</strong>
                </p>
                <p className="mt-1 text-xs text-ink-muted">
                  كل {r.rate} تفاعلات تمنحك نقطة
                </p>
                <p className="mt-4 text-xs font-black text-brand">
                  بإنهائه تكون جمعت {(i + 1) * 50} شيكل
                </p>
              </article>
            </Reveal>
          ))}
        </div>
        <Reveal delay={120}>
          <p className="mt-6 rounded-2xl bg-brand-light/40 p-5 text-center text-sm leading-relaxed text-ink">
            بعد البلاتيني لا تتوقف المكافآت: يتضاعف الهدف في كل مرة (1600، 3200 …)
            وتبقى المكافأة 50 شيكل.
          </p>
        </Reveal>
      </section>

      <section className="container-site mt-20 mb-6">
        <SectionHeader kicker="من أين تأتي" title="طرق جمع النقاط" emoji="✨" />
        <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {EARN.map((e, i) => (
            <Reveal key={e.t} delay={(i % 3) * 90}>
              <li className="card flex h-full items-start gap-4 p-5">
                <span className="mt-0.5 grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-brand-light text-brand-dark">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                    <path d="M12 2l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4L7.5 15.8l.9-5L4.8 7.3l5-.7L12 2Z" />
                  </svg>
                </span>
                <span className="min-w-0">
                  <span className="block font-black text-ink">{e.t}</span>
                  <span className="block text-xs text-ink-muted">{e.d}</span>
                  <span className="mt-1 block text-sm font-black text-brand-dark">{e.v}</span>
                </span>
              </li>
            </Reveal>
          ))}
        </ul>
      </section>
    </>
  );
}
