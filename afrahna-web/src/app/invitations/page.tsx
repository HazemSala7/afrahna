import type { Metadata } from 'next';
import Link from 'next/link';

import { Aurora, Flourish, Petals, Sparkles } from '@/components/decor';
import { Reveal } from '@/components/motion';
import { Empty, Img, SectionHeader } from '@/components/ui';
import { allTemplates } from '@/lib/catalog';

export const metadata: Metadata = {
  title: 'الدعوات الإلكترونية',
  description:
    'صمّم دعوة زفافك الإلكترونية من قوالب أفراحنا، شاركها برابط واحد، وتابع'
    + ' ردود المدعوّين أولاً بأول.',
};

const STEPS = [
  { n: '١', t: 'اختر التصميم', d: 'قوالب جاهزة بألوان وخطوط ومؤثّرات مختلفة.' },
  { n: '٢', t: 'اكتب تفاصيلك', d: 'الأسماء، الموعد، المكان، وكلمتك للمدعوّين.' },
  { n: '٣', t: 'شارك الرابط', d: 'رابط واحد يفتح الدعوة على أي جهاز، بلا تطبيق.' },
  { n: '٤', t: 'تابع الردود', d: 'من سيحضر ومن اعتذر، ورسائل التهنئة، في مكان واحد.' },
];

export default async function InvitationsPage() {
  const templates = (await allTemplates()).filter((t) => t.is_active !== false);

  return (
    <>
      <section className="grain relative overflow-hidden border-b border-brand-light/60 bg-gradient-to-b from-cream-surface to-cream">
        <Aurora />
        <Sparkles count={12} />
        <Petals count={10} />
        <div className="container-site relative py-16 text-center">
          <Reveal>
            <span className="chip">مجاناً مع تطبيق أفراحنا</span>
            <h1 className="mt-4 text-4xl font-black leading-tight text-ink sm:text-5xl">
              دعوة زفافك، <span className="foil">برابط واحد</span>
            </h1>
            <p className="mx-auto mt-5 max-w-2xl text-base leading-loose text-ink-muted">
              صمّم دعوتك من قالب جاهز، أرسلها في واتساب، وتابع من سيحضر — بلا
              مطابع، بلا مواعيد تسليم، وبلا أن يحتاج المدعوّ لتحميل أي شيء.
            </p>
            <div className="mt-8 flex flex-wrap justify-center gap-3">
              <Link href="/app" className="btn-primary">
                ابدأ من التطبيق
              </Link>
              <Link href="/contact" className="btn-ghost">
                تحتاج مساعدة؟
              </Link>
            </div>
          </Reveal>
          <Flourish className="mx-auto mt-10 w-40 opacity-70" />
        </div>
      </section>

      <section className="container-site mt-16">
        <SectionHeader kicker="أربع خطوات" title="كيف تعمل؟" />
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {STEPS.map((s, i) => (
            <Reveal key={s.n} delay={i * 90}>
              <article className="card h-full p-6">
                <span className="grid h-11 w-11 place-items-center rounded-xl bg-brand-light text-lg font-black text-brand-dark">
                  {s.n}
                </span>
                <h3 className="mt-4 font-black text-ink">{s.t}</h3>
                <p className="mt-1 text-sm leading-relaxed text-ink-muted">{s.d}</p>
              </article>
            </Reveal>
          ))}
        </div>
      </section>

      <section className="container-site mt-20">
        <SectionHeader
          kicker={`${templates.length} تصميماً`}
          title="اختر قالبك"
          emoji="💌"
        />
        {templates.length === 0 ? (
          <Empty title="لا توجد قوالب معروضة الآن" />
        ) : (
          <div className="grid grid-cols-2 gap-5 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6">
            {templates.map((t, i) => (
              <Reveal key={t.id} delay={(i % 4) * 80}>
                <article className="card card-hover overflow-hidden">
                  <Img
                    src={t.preview_image || t.background_image}
                    alt={t.name ?? 'قالب دعوة'}
                    ratio="aspect-[3/4]"
                    eager={i < 4}
                  />
                  <div className="flex items-center justify-between gap-2 p-4">
                    <h3 className="line-clamp-1 text-sm font-black text-ink">
                      {t.name ?? 'قالب'}
                    </h3>
                    {/* The template's own palette, as three dots. */}
                    <span className="flex shrink-0 gap-1" aria-hidden>
                      {[t.bg_color, t.text_color, t.accent_color]
                        .filter(Boolean)
                        .map((c, j) => (
                          <span
                            key={j}
                            className="h-3.5 w-3.5 rounded-full border border-black/10"
                            style={{ background: c as string }}
                          />
                        ))}
                    </span>
                  </div>
                </article>
              </Reveal>
            ))}
          </div>
        )}
      </section>
    </>
  );
}
