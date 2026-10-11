import type { Metadata } from 'next';

import PageHero from '@/components/PageHero';
import { Reveal } from '@/components/motion';

export const metadata: Metadata = {
  title: 'تواصل معنا',
  description: 'نسعد بأسئلتك واقتراحاتك. راسلنا عبر واتساب أو البريد الإلكتروني وسنردّ في أقرب وقت.',
};

export default function Page() {
  return (
    <div className="container-site py-10">
      <PageHero kicker="نسمع منك" title="تواصل معنا" />
      <Reveal>
      <p className="mx-auto max-w-3xl text-center text-[15px] leading-loose text-ink-muted">
        نسعد بأسئلتك واقتراحاتك. راسلنا عبر واتساب أو البريد الإلكتروني وسنردّ في أقرب وقت.
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
