import type { Metadata } from 'next';

import PageHero from '@/components/PageHero';
import { Reveal } from '@/components/motion';

export const metadata: Metadata = {
  title: 'من نحن',
  description: 'أفراحنا منصّة فلسطينية تجمع كل ما تحتاجه مناسبتك في مكان واحد: قاعات وتصوير وأزياء وتجميل وضيافة وحلويات وهدايا ودعوات إلكترونية. بدأنا لأن تنظيم فرح ',
};

export default function Page() {
  return (
    <div className="container-site py-10">
      <PageHero kicker="المنصّة" title="من نحن" />
      <Reveal>
      <p className="mx-auto max-w-3xl text-center text-[15px] leading-loose text-ink-muted">
        أفراحنا منصّة فلسطينية تجمع كل ما تحتاجه مناسبتك في مكان واحد: قاعات وتصوير وأزياء وتجميل وضيافة وحلويات وهدايا ودعوات إلكترونية. بدأنا لأن تنظيم فرح واحد كان يعني عشرات المكالمات والبحث المتفرّق بين الصفحات — فجمعنا المحلات الموثوقة وأعمالها وأسعارها في دليل واحد، وأضفنا إليه أدوات التخطيط: منسّق المناسبة، قائمة المهام، والدعوات.
      </p>
      </Reveal>
      <Reveal delay={120}>
      <div className="mt-10 flex flex-wrap justify-center gap-3">
        <a href="https://wa.me/970599000000" className="btn bg-[#25D366] text-white">
          واتساب
        </a>
        <a href="mailto:info@afrahna.co" className="btn-ghost">info@afrahna.co</a>
      </div>
      </Reveal>
    </div>
  );
}
