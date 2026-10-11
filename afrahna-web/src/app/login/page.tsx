import type { Metadata } from 'next';
import { Suspense } from 'react';

import LoginForm from '@/components/account/LoginForm';
import { Aurora, Petals, Sparkles } from '@/components/decor';
import { Reveal } from '@/components/motion';

export const metadata: Metadata = {
  title: 'تسجيل الدخول',
  description: 'ادخل إلى حسابك في أفراحنا لتحجز، تطلب، وتتابع ردود المحلات أولاً بأول.',
  robots: { index: false, follow: true },
};

export default function LoginPage() {
  return (
    <div className="grain relative overflow-hidden">
      <Aurora />
      <Sparkles count={10} />
      <Petals count={6} />
      <div className="container-site relative py-12 sm:py-16">
        <Reveal kind="pop">
          <div className="mb-8 text-center">
            <h1 className="text-3xl font-black text-ink sm:text-4xl">
              أهلاً بك في <span className="foil">أفراحنا</span>
            </h1>
            <p className="mx-auto mt-3 max-w-md text-sm leading-relaxed text-ink-muted">
              احجز، اطلب، وتابع كل رد من المحلات لحظة بلحظة.
            </p>
          </div>
        </Reveal>
        <Suspense fallback={<div className="card mx-auto h-96 max-w-md skeleton" />}>
          <LoginForm />
        </Suspense>
      </div>
    </div>
  );
}
