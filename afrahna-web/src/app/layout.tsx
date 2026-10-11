import type { Metadata, Viewport } from 'next';
import { Cairo } from 'next/font/google';

import { SITE_URL as SITE } from '@/lib/api';
import { SessionProvider } from '@/lib/session';
import LiveNotices from '@/components/account/LiveNotices';
import { Toaster } from '@/components/account/feedback';
import BottomNav from '@/components/BottomNav';
import Footer from '@/components/Footer';
import Header from '@/components/Header';
import Intro, { INTRO_SCRIPT } from '@/components/Intro';
import Ribbon from '@/components/Ribbon';
import { BackToTop, CursorGlow, ScrollProgress } from '@/components/chrome';
import '@/styles/globals.css';

// Self-hosted by Next at build time: the font ships from our own domain with
// the page, so there is no second DNS lookup and no flash of unstyled Arabic.
const arabic = Cairo({
  subsets: ['arabic', 'latin'],
  weight: ['400', '600', '700', '900'],
  display: 'swap',
  variable: '--font-arabic',
});

const TITLE = 'أفراحنا — كل ما يلزم مناسبتك في مكان واحد';
const DESCRIPTION =
  'دليل خدمات الأفراح والمناسبات في فلسطين: قاعات، تصوير، فساتين، تجميل، ضيافة'
  + ' وحلويات، دعوات إلكترونية وعروض حصرية — من مئات المحلات الموثوقة.';

export const metadata: Metadata = {
  metadataBase: new URL(SITE),
  title: { default: TITLE, template: '%s · أفراحنا' },
  description: DESCRIPTION,
  applicationName: 'أفراحنا',
  keywords: [
    'أفراح', 'أعراس', 'قاعات أفراح', 'تصوير أعراس', 'فساتين زفاف',
    'تجميل وعناية', 'دعوات إلكترونية', 'فلسطين', 'أفراحنا',
  ],
  openGraph: {
    type: 'website',
    siteName: 'أفراحنا',
    locale: 'ar_PS',
    title: TITLE,
    description: DESCRIPTION,
    url: SITE,
    images: [{ url: '/og.jpg', width: 1200, height: 630, alt: 'أفراحنا' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: TITLE,
    description: DESCRIPTION,
    images: ['/og.jpg'],
  },
  robots: { index: true, follow: true },
  icons: { icon: '/favicon.png', apple: '/favicon.png' },
};

export const viewport: Viewport = {
  themeColor: '#FAF3EC',
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl" className={arabic.variable}>
      <head>
        {/*
          Decides — before the first paint — whether this visit has already
          seen the curtain, so it is never shown and then snatched away. Also
          arms the failsafe that dismisses it if the animation never runs.
        */}
        {/* eslint-disable-next-line react/no-danger */}
        <script dangerouslySetInnerHTML={{ __html: INTRO_SCRIPT }} />

        {/*
          The reveal animations start at opacity 0 and are switched on by an
          IntersectionObserver. If that script never runs — JavaScript off, a
          blocker, an old crawler — every section below the fold would stay
          invisible on a page whose whole point is that it works without it.
          The curtain is hidden outright in that case: with no script to
          dismiss it, it would sit over the page for good.
        */}
        <noscript>
          {/* eslint-disable-next-line react/no-danger */}
          <style
            dangerouslySetInnerHTML={{
              __html:
                '.reveal,.stagger>*{opacity:1 !important;animation:none !important}'
                + '.intro{display:none !important}',
            }}
          />
        </noscript>
      </head>
      <body className="flex min-h-screen flex-col">
        {/* Who is visiting, for the few parts of the page that care: the
            basket, the bell, booking and ordering. Everything else is still
            the same static HTML for everyone. */}
        <SessionProvider>
        {/* First stop for a keyboard or screen reader: past the whole nav. */}
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:absolute focus:right-4
                     focus:top-4 focus:z-50 focus:rounded-lg focus:bg-brand
                     focus:px-4 focus:py-2 focus:text-white"
        >
          تخطَّ إلى المحتوى
        </a>
        <Intro />
        <ScrollProgress />
        <CursorGlow />
        <Ribbon />
        <Header />
        <main id="main" className="flex-1">
          {children}
        </main>
        <Footer />
        <BottomNav />
        <BackToTop />
        <LiveNotices />
        <Toaster />
        </SessionProvider>
      </body>
    </html>
  );
}
