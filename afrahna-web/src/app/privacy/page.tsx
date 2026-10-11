import type { Metadata } from 'next';

import PageHero from '@/components/PageHero';
import { Reveal } from '@/components/motion';

export const metadata: Metadata = {
  title: 'سياسة الخصوصية',
  description: 'نجمع الحد الأدنى من البيانات اللازم لتشغيل الخدمة: الاسم ورقم الهاتف عند إنشاء الحساب، وبيانات الاستخدام لتحسين التطبيق. لا نبيع بياناتك ولا نشاركها م',
};

export default function Page() {
  return (
    <div className="container-site py-10">
      <PageHero kicker="الشفافية" title="سياسة الخصوصية" />
      <Reveal>
      <p className="mx-auto max-w-3xl text-center text-[15px] leading-loose text-ink-muted">
        نجمع الحد الأدنى من البيانات اللازم لتشغيل الخدمة: الاسم ورقم الهاتف عند إنشاء الحساب، وبيانات الاستخدام لتحسين التطبيق. لا نبيع بياناتك ولا نشاركها مع أطراف ثالثة لأغراض إعلانية. يمكنك طلب حذف حسابك وبياناته في أي وقت من داخل التطبيق أو بمراسلتنا.
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
