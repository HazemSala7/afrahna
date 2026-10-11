import type { Metadata } from 'next';

import NoticeList from '@/components/account/NoticeList';
import PageHero from '@/components/PageHero';

export const metadata: Metadata = {
  title: 'الإشعارات',
  robots: { index: false, follow: false },
};

export default function NotificationsPage() {
  return (
    <div className="container-site py-8">
      <PageHero
        kicker="أولاً بأول"
        title={<>الإشعارات</>}
        subtitle="ردود المحلات، طلبات الزبائن، والعروض — كل ما يخصّك في مكان واحد."
      />
      <NoticeList />
    </div>
  );
}
