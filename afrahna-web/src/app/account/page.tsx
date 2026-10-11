import type { Metadata } from 'next';

import AccountHome from '@/components/account/AccountHome';

export const metadata: Metadata = {
  title: 'حسابي',
  robots: { index: false, follow: false },
};

export default function AccountPage() {
  return (
    <div className="container-site py-10">
      <AccountHome />
    </div>
  );
}
