import type { Metadata } from 'next';
import { Suspense } from 'react';

import TradeBoard from '@/components/account/TradeBoard';
import PageHero from '@/components/PageHero';

export const metadata: Metadata = {
  title: 'مناسباتي',
  robots: { index: false, follow: false },
};

export default function BookingsPage() {
  return (
    <div className="container-site py-8">
      <PageHero
        kicker="المتابعة"
        title={<>مناسباتي <span className="foil">وحجوزاتي</span></>}
        subtitle="كل حجز طلبته، ورد المحل عليه، وموعده — تتحدّث من تلقاء نفسها."
      />
      <Suspense>
        <TradeBoard kind="booking" />
      </Suspense>
    </div>
  );
}
