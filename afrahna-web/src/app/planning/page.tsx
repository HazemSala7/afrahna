import type { Metadata } from 'next';
import Link from 'next/link';

import { Budget, Checklist } from '@/components/Planner';
import { Reveal } from '@/components/motion';
import { SectionHeader } from '@/components/ui';
import { allTaskTemplates } from '@/lib/catalog';

export const metadata: Metadata = {
  title: 'خطّطي فرحك',
  description:
    'قائمة مهام جاهزة لتحضير الزفاف وحاسبة ميزانية — خطّط كل تفصيل من المتصفح،'
    + ' ويُحفظ تلقائياً على جهازك.',
};

/** The fallback list, used when the dashboard has not published one. */
const DEFAULT_TASKS = [
  'تحديد الموعد والميزانية',
  'حجز القاعة',
  'اختيار المصوّر',
  'فستان العروس وبدلة العريس',
  'تجهيز قائمة المدعوّين',
  'تصميم الدعوات وإرسالها',
  'حجز صالون التجميل',
  'اختيار الضيافة والحلويات',
  'ترتيب السيارات والزفة',
  'التوزيعات والهدايا',
  'بروفة نهائية قبل الموعد',
];

export default async function PlanningPage() {
  const templates = await allTaskTemplates();
  const published = templates
    .filter((t) => t.is_active !== false)
    .flatMap((t) => t.items ?? [])
    .map((i) => (i.title_ar || i.title || '').trim())
    .filter(Boolean);

  const tasks = published.length >= 4 ? published : DEFAULT_TASKS;

  return (
    <div className="container-site py-12">
      <Reveal>
        <header className="max-w-2xl">
          <span className="chip">أدوات مجانية</span>
          <h1 className="mt-4 text-4xl font-black text-ink sm:text-5xl">
            خطّطي <span className="foil">فرحك</span>
          </h1>
          <p className="mt-4 text-base leading-loose text-ink-muted">
            قائمة مهام جاهزة وحاسبة ميزانية تعملان هنا مباشرة. كل ما تكتبه
            يُحفظ على جهازك وحده — لا حساب، ولا يغادر متصفّحك.
          </p>
        </header>
      </Reveal>

      <div className="mt-10 grid gap-6 lg:grid-cols-2 lg:items-start">
        <Reveal>
          <Checklist items={tasks} />
        </Reveal>
        <Reveal delay={110}>
          <Budget />
        </Reveal>
      </div>

      <section className="mt-20">
        <SectionHeader kicker="الخطوة التالية" title="أكمل التحضير" />
        <div className="grid gap-5 sm:grid-cols-3">
          {[
            { href: '/invitations', t: 'دعوة إلكترونية', d: 'صمّمها وشاركها برابط.' },
            { href: '/vendors', t: 'احجز محلاتك', d: 'قاعات، تصوير، تجميل وأكثر.' },
            { href: '/app', t: 'أكمل من التطبيق', d: 'منسّق المناسبة والتقويم الذكي.' },
          ].map((c, i) => (
            <Reveal key={c.href} delay={i * 90}>
              <Link href={c.href} className="card card-hover block h-full p-6">
                <h3 className="font-black text-ink">{c.t}</h3>
                <p className="mt-1 text-sm text-ink-muted">{c.d}</p>
                <span className="mt-4 block h-[3px] w-10 rounded-full bg-gradient-to-l from-brand-accent to-brand-dark" />
              </Link>
            </Reveal>
          ))}
        </div>
      </section>
    </div>
  );
}
