import type { Metadata } from 'next';

import CartView from '@/components/commerce/CartView';
import PageHero from '@/components/PageHero';

export const metadata: Metadata = {
  title: 'السلة',
  robots: { index: false, follow: true },
};

export default function CartPage() {
  return (
    <div className="container-site py-8">
      <PageHero
        kicker="طلبك"
        title={<>السلة</>}
        subtitle="أرسل طلبك إلى المحل مباشرة، وتابع تأكيده وتجهيزه خطوة بخطوة."
      />
      <div className="mx-auto max-w-4xl">
        <CartView />
      </div>
    </div>
  );
}
