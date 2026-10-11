import type { Metadata } from 'next';
import { Suspense } from 'react';

import TradeBoard from '@/components/account/TradeBoard';
import PageHero from '@/components/PageHero';

export const metadata: Metadata = {
  title: 'طلباتي',
  robots: { index: false, follow: false },
};

export default function OrdersPage() {
  return (
    <div className="container-site py-8">
      <PageHero
        kicker="المتابعة"
        title={<>طلباتي <span className="foil">خطوة بخطوة</span></>}
        subtitle="كل طلبية أرسلتها، وأين وصلت، ومتى رد المتجر — تتحدّث من تلقاء نفسها."
      />
      <Suspense>
        <TradeBoard kind="order" />
      </Suspense>
    </div>
  );
}
