'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';

export interface Entry {
  /** id, name, category, city, logo, href — short keys keep the JSON small. */
  i: number;
  n: string;
  c: string;
  t: string;
  l: string;
  h: string;
}

export default function SearchClient({ index }: { index: Entry[] }) {
  const [q, setQ] = useState('');

  const results = useMemo(() => {
    const term = q.trim().toLowerCase();
    if (term.length < 2) return [];
    return index
      .filter(
        (e) =>
          e.n.toLowerCase().includes(term) ||
          e.c.toLowerCase().includes(term) ||
          e.t.toLowerCase().includes(term),
      )
      .slice(0, 60);
  }, [q, index]);

  return (
    <div className="container-site py-10">
      <h1 className="text-3xl font-black text-ink sm:text-4xl">بحث</h1>

      <input
        type="search"
        autoFocus
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder="اسم محل، خدمة، أو مدينة…"
        aria-label="ابحث"
        className="mt-6 h-14 w-full rounded-xl border border-brand-light bg-white px-4
                   text-base outline-none transition-colors placeholder:text-ink-muted
                   focus:border-brand"
      />

      <p className="mt-3 text-sm text-ink-muted">
        {q.trim().length < 2
          ? `ابحث في ${index.length.toLocaleString('ar-EG')} محل`
          : `${results.length.toLocaleString('ar-EG')} نتيجة`}
      </p>

      <ul className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
        {results.map((e) => (
          <li key={e.i}>
            <Link href={e.h} className="card card-hover flex items-center gap-4 p-3">
              {e.l ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={e.l}
                  alt=""
                  width={56}
                  height={56}
                  loading="lazy"
                  decoding="async"
                  className="h-14 w-14 shrink-0 rounded-xl object-cover"
                />
              ) : (
                <span className="h-14 w-14 shrink-0 rounded-xl bg-brand-light/50" />
              )}
              <span className="min-w-0">
                <span className="block truncate font-black text-ink">{e.n}</span>
                <span className="block truncate text-xs text-ink-muted">
                  {[e.c, e.t].filter(Boolean).join(' · ')}
                </span>
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
