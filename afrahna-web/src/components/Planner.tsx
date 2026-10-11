'use client';

import { useEffect, useMemo, useState } from 'react';

/**
 * The checklist and the budget, both working, both kept in the browser.
 *
 * The site is static and the reader is not signed in, so there is nowhere to
 * save this but their own device — `localStorage` is exactly right for it: the
 * list survives closing the tab, never travels anywhere, and needs no account
 * to be useful. Signing in to move it onto the phone is what the app is for.
 *
 * Every read and write is wrapped: a private window, cleared site data or a
 * browser set to refuse storage must degrade to "the tool still works, it just
 * forgets", never to a blank screen.
 */

function useStored<T>(key: string, initial: T) {
  const [value, setValue] = useState<T>(initial);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(key);
      if (raw) setValue(JSON.parse(raw) as T);
    } catch {
      /* storage unavailable — carry on with the defaults */
    }
    setReady(true);
  }, [key]);

  useEffect(() => {
    if (!ready) return;
    try {
      window.localStorage.setItem(key, JSON.stringify(value));
    } catch {
      /* nothing to do: the tool works, it just will not remember */
    }
  }, [key, value, ready]);

  return [value, setValue, ready] as const;
}

// ---------------------------------------------------------------- checklist

export function Checklist({ items }: { items: string[] }) {
  const [done, setDone] = useStored<Record<string, boolean>>('afrahna.checklist', {});
  const [extra, setExtra] = useStored<string[]>('afrahna.checklist.extra', []);
  const [draft, setDraft] = useState('');

  const all = useMemo(() => [...items, ...extra], [items, extra]);
  const completed = all.filter((t) => done[t]).length;
  const pct = all.length ? Math.round((completed / all.length) * 100) : 0;

  return (
    <div className="card p-6">
      <div className="flex items-end justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-ink">قائمة مهامك</h2>
          <p className="mt-1 text-sm text-ink-muted">
            {completed} من {all.length} مهمة
          </p>
        </div>
        <span className="text-3xl font-black text-brand-dark">{pct}%</span>
      </div>

      <div className="mt-4 h-2.5 overflow-hidden rounded-full bg-brand-light/60">
        <div
          className="h-full rounded-full bg-gradient-to-l from-brand-accent to-brand-dark transition-[width] duration-700 ease-out"
          style={{ width: `${pct}%` }}
        />
      </div>

      <ul className="mt-6 grid gap-2">
        {all.map((task) => (
          <li key={task}>
            <label
              className={`flex cursor-pointer items-center gap-3 rounded-xl border p-3 transition-colors ${
                done[task]
                  ? 'border-brand-light bg-cream text-ink-muted'
                  : 'border-brand-light/70 bg-white hover:border-brand'
              }`}
            >
              <input
                type="checkbox"
                checked={!!done[task]}
                onChange={(e) =>
                  setDone((d) => ({ ...d, [task]: e.target.checked }))
                }
                className="h-5 w-5 shrink-0 accent-[#B8835A]"
              />
              <span className={`text-sm font-bold ${done[task] ? 'line-through' : ''}`}>
                {task}
              </span>
            </label>
          </li>
        ))}
      </ul>

      <form
        className="mt-4 flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          const t = draft.trim();
          if (!t || all.includes(t)) return;
          setExtra((x) => [...x, t]);
          setDraft('');
        }}
      >
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="أضف مهمة من عندك…"
          aria-label="مهمة جديدة"
          className="h-12 w-full rounded-xl border border-brand-light bg-white px-4 text-sm outline-none focus:border-brand"
        />
        <button type="submit" className="btn-primary shrink-0">
          إضافة
        </button>
      </form>
    </div>
  );
}

// ------------------------------------------------------------------- budget

const LINES = [
  { key: 'hall', label: 'القاعة', hint: 'الإيجار والضيافة' },
  { key: 'photo', label: 'التصوير', hint: 'فوتو وفيديو' },
  { key: 'dress', label: 'الفستان والبدلة', hint: 'شراء أو إيجار' },
  { key: 'beauty', label: 'التجميل', hint: 'مكياج وشعر' },
  { key: 'food', label: 'الضيافة والحلويات', hint: 'البوفيه والكيك' },
  { key: 'cars', label: 'السيارات', hint: 'الزفة والتنقّل' },
  { key: 'gifts', label: 'التوزيعات والهدايا', hint: 'للمدعوّين' },
  { key: 'other', label: 'أخرى', hint: 'ما لم يُذكر' },
];

export function Budget() {
  const [total, setTotal] = useStored<number>('afrahna.budget.total', 20000);
  const [spent, setSpent] = useStored<Record<string, number>>('afrahna.budget', {});

  const used = LINES.reduce((sum, l) => sum + (Number(spent[l.key]) || 0), 0);
  const left = total - used;
  const pct = total > 0 ? Math.min(100, Math.round((used / total) * 100)) : 0;

  return (
    <div className="card p-6">
      <h2 className="text-xl font-black text-ink">ميزانية فرحك</h2>
      <p className="mt-1 text-sm text-ink-muted">
        اكتب ميزانيتك ووزّعها على البنود — يُحفظ على جهازك تلقائياً.
      </p>

      <label className="mt-5 block">
        <span className="text-sm font-bold text-ink">الميزانية الكاملة (₪)</span>
        <input
          type="number"
          min={0}
          inputMode="numeric"
          value={total}
          onChange={(e) => setTotal(Number(e.target.value) || 0)}
          className="mt-2 h-12 w-full rounded-xl border border-brand-light bg-white px-4 text-lg font-black outline-none focus:border-brand"
        />
      </label>

      <div className="mt-5 grid gap-3 sm:grid-cols-3">
        <Figure label="الميزانية" value={total} />
        <Figure label="المصروف" value={used} tone="brand" />
        <Figure label="المتبقّي" value={left} tone={left < 0 ? 'over' : 'good'} />
      </div>

      <div className="mt-4 h-2.5 overflow-hidden rounded-full bg-brand-light/60">
        <div
          className={`h-full rounded-full transition-[width] duration-700 ease-out ${
            left < 0
              ? 'bg-sale'
              : 'bg-gradient-to-l from-brand-accent to-brand-dark'
          }`}
          style={{ width: `${pct}%` }}
        />
      </div>
      {left < 0 && (
        <p className="mt-2 text-sm font-bold text-sale">
          تجاوزت ميزانيتك بـ{Math.abs(left).toLocaleString('ar-EG')} ₪
        </p>
      )}

      <ul className="mt-6 grid gap-3">
        {LINES.map((l) => (
          <li key={l.key} className="flex items-center gap-3">
            <span className="min-w-0 flex-1">
              <span className="block text-sm font-bold text-ink">{l.label}</span>
              <span className="block text-xs text-ink-muted">{l.hint}</span>
            </span>
            <input
              type="number"
              min={0}
              inputMode="numeric"
              value={spent[l.key] ?? ''}
              placeholder="0"
              aria-label={l.label}
              onChange={(e) =>
                setSpent((s) => ({ ...s, [l.key]: Number(e.target.value) || 0 }))
              }
              className="h-11 w-32 shrink-0 rounded-xl border border-brand-light bg-white px-3 text-left text-sm font-bold outline-none focus:border-brand"
            />
          </li>
        ))}
      </ul>
    </div>
  );
}

function Figure({
  label,
  value,
  tone = 'plain',
}: {
  label: string;
  value: number;
  tone?: 'plain' | 'brand' | 'good' | 'over';
}) {
  const colour = {
    plain: 'text-ink',
    brand: 'text-brand-dark',
    good: 'text-emerald-700',
    over: 'text-sale',
  }[tone];
  return (
    <div className="rounded-xl border border-brand-light bg-cream/60 p-4 text-center">
      <div className={`text-xl font-black ${colour}`}>
        {value.toLocaleString('ar-EG')} ₪
      </div>
      <div className="mt-0.5 text-xs text-ink-muted">{label}</div>
    </div>
  );
}
