'use client';

import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';

/** Where a page for members meets a visitor who has not signed in. */
export default function SignInGate({ title, hint }: { title: string; hint?: string }) {
  const pathname = usePathname();
  const params = useSearchParams();
  const here = pathname + (params.toString() ? `?${params.toString()}` : '');
  const next = encodeURIComponent(here);

  return (
    <div className="card grain relative mx-auto grid max-w-lg place-items-center gap-3 overflow-hidden px-6 py-14 text-center">
      <div className="float text-4xl" aria-hidden>🔐</div>
      <h2 className="text-xl font-black text-ink">{title}</h2>
      {hint && <p className="max-w-sm text-sm leading-relaxed text-ink-muted">{hint}</p>}
      <div className="mt-3 flex flex-wrap justify-center gap-3">
        <Link href={`/login?next=${next}`} className="btn-primary">
          تسجيل الدخول
        </Link>
        <Link href={`/login?mode=register&next=${next}`} className="btn-ghost">
          إنشاء حساب
        </Link>
      </div>
    </div>
  );
}
