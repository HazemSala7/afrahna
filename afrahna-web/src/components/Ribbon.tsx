import Link from 'next/link';

/**
 * The thin gold band across the very top of the page.
 *
 * It is the first thing the eye lands on, and its job is to say "there is a
 * lot going on here" in one line: the site's promises, scrolling past, in
 * gold, above everything else.
 *
 * Not sticky. A permanent strip of moving text at the top of a page you are
 * trying to read is a nuisance — it scrolls away with the hero and the header
 * takes over from there.
 */
const MESSAGES = [
  { text: 'مئات المحلات الموثوقة في مكان واحد', icon: '✦' },
  { text: 'دعوات إلكترونية جاهزة بدقائق', icon: '💌' },
  { text: 'عروض حصرية لعملاء أفراحنا', icon: '🎁' },
  { text: 'خطّطي فرحك من جوالك', icon: '✦' },
  { text: 'كل 100 نقطة = 50 شيكل', icon: '⭐' },
  { text: 'قاعات · تصوير · فساتين · تجميل · ضيافة', icon: '✦' },
];

export default function Ribbon() {
  return (
    // Below the header's z-40 on purpose: the ribbon scrolls away while the
    // header sticks, and anything above the header would slide over the top of
    // it on the way past.
    <div
      className="marquee sweep relative z-20 overflow-hidden bg-gradient-to-l from-brand-dark via-brand to-brand-accent text-white"
      role="complementary"
      aria-label="روابط سريعة"
    >

      {/* Two identical halves scrolling as one strip: when the first has
          travelled its own width the second is exactly where it started, so
          the loop has no seam. Pauses on hover so a line can be read. */}
      <div className="marquee-track relative z-10 flex w-max items-center gap-8 py-2">
        {[0, 1].map((half) => (
          <div key={half} className="flex shrink-0 items-center gap-8" aria-hidden={half === 1}>
            {MESSAGES.map((m, i) => (
              <span
                key={`${half}-${i}`}
                className="flex items-center gap-2 whitespace-nowrap text-[11px] font-black tracking-wide sm:text-xs"
              >
                <span className="text-[10px] opacity-80" aria-hidden>
                  {m.icon}
                </span>
                {m.text}
              </span>
            ))}
          </div>
        ))}
      </div>

      {/* One real link, sitting on top of the strip at the start edge, so the
          band is not purely decorative on a page this prominent. */}
      <Link
        href="/offers"
        className="absolute inset-y-0 left-0 z-20 hidden items-center gap-1 bg-brand-dark px-4 text-[11px] font-black
                   shadow-[-12px_0_18px_rgba(139,90,60,0.6)] transition-colors hover:bg-ink sm:flex"
      >
        شوف العروض
        <span aria-hidden>←</span>
      </Link>
    </div>
  );
}
