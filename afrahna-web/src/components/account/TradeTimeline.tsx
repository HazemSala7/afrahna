'use client';

import {
  closedBy, nextHint, parseDate, shortWhen, stepLabel, stepsFor, longWhen,
  type StatusEvent, type TradeKind, type Viewer,
} from '@/lib/trade';

/**
 * Where an order or a booking stands, drawn as the road it travels: every step
 * reached lit in gold with when it happened, the ones ahead waiting, and — if
 * it was turned down or called off — who did it and in what words.
 *
 * The same component as the app's timeline, in the site's cream and gold.
 */
export default function TradeTimeline({
  kind,
  status,
  log,
  createdAt,
  updatedAt,
  viewer,
}: {
  kind: TradeKind;
  status: string;
  log?: StatusEvent[] | null;
  createdAt?: string | null;
  updatedAt?: string | null;
  viewer: Viewer;
}) {
  const steps = stepsFor(kind);
  const history = (log ?? []).filter((e) => e && e.status);
  const closedShort = status === 'cancelled' || status === 'rejected';

  let reached = 0;
  if (closedShort) {
    for (const e of history) reached = Math.max(reached, steps.indexOf(e.status));
  } else {
    reached = Math.max(0, steps.indexOf(status));
  }

  const reachedAt = (step: string): Date | null => {
    for (let i = history.length - 1; i >= 0; i--) {
      if (history[i].status === step) return parseDate(history[i].at);
    }
    if (step === 'pending') return parseDate(createdAt);
    if (step === status) return parseDate(updatedAt);
    return null;
  };

  const closing = [...history].reverse().find((e) => e.status === status);
  const closedAt = parseDate(closing?.at) ?? parseDate(updatedAt);

  let last: Date | null = null;
  for (const e of history) {
    const d = parseDate(e.at);
    if (d && (!last || d > last)) last = d;
  }
  last ??= parseDate(status === 'pending' ? createdAt : updatedAt);

  const haltLabel = status === 'rejected'
    ? (kind === 'order' ? 'رُفضت' : 'رُفض')
    : (kind === 'order' ? 'أُلغيت' : 'أُلغي');

  return (
    <div className="rounded-2xl border border-brand-light/80 bg-gradient-to-b from-cream-surface to-white p-3 sm:p-4">
      <ol className="flex items-start" aria-label="مراحل الطلب">
        {steps.map((step, i) => {
          const halted = closedShort && i === reached + 1;
          const done = closedShort ? i <= reached : i < reached || (i === reached && status === 'completed');
          const current = !closedShort && i === reached && status !== 'completed';
          const lit = done || current;
          const when = i <= reached ? reachedAt(step) : halted ? closedAt : null;
          const inLit = i > 0 && i <= reached;
          const outLit = i < steps.length - 1 && i < reached;

          return (
            <li key={step} className="flex min-w-0 flex-1 flex-col items-center" aria-current={current ? 'step' : undefined}>
              <div className="flex w-full items-center">
                <span
                  className={`h-[3px] flex-1 rounded-full ${i === 0 ? 'invisible' : inLit ? 'bg-gradient-to-l from-brand-accent to-brand' : 'bg-brand-light'}`}
                  aria-hidden
                />
                <span
                  className={`relative grid h-7 w-7 shrink-0 place-items-center rounded-full text-[11px] font-black transition-all
                    ${halted
                      ? 'border-2 border-sale bg-red-50 text-sale'
                      : done
                        ? 'bg-gradient-to-br from-brand-accent to-brand-dark text-white shadow-[0_4px_12px_rgba(184,131,90,0.45)]'
                        : current
                          ? 'border-2 border-brand bg-white text-brand-dark'
                          : 'border border-brand-light bg-white text-ink-muted'}`}
                >
                  {current && (
                    <span
                      className="pointer-events-none absolute inset-0 rounded-full bg-brand-accent"
                      style={{ animation: 'pulse-ring 2.4s ease-out infinite' }}
                      aria-hidden
                    />
                  )}
                  <span className="relative">
                    {halted ? '✕' : done ? '✓' : current ? '●' : i + 1}
                  </span>
                </span>
                <span
                  className={`h-[3px] flex-1 rounded-full ${i === steps.length - 1 ? 'invisible' : outLit ? 'bg-gradient-to-l from-brand-accent to-brand' : 'bg-brand-light'}`}
                  aria-hidden
                />
              </div>
              <span
                className={`mt-1.5 max-w-full truncate text-[11px] sm:text-xs ${
                  halted ? 'font-black text-sale' : lit ? 'font-black text-ink' : 'font-semibold text-ink-muted'
                }`}
              >
                {halted ? haltLabel : stepLabel(kind, step)}
              </span>
              <span className="h-4 text-[10px] text-ink-muted" title={when ? longWhen(when) : undefined}>
                {when ? shortWhen(when) : ''}
              </span>
            </li>
          );
        })}
      </ol>

      {closedShort ? (
        <div className="mt-3 rounded-xl border border-red-200 bg-red-50/70 p-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-black text-sale">
              {closedBy(kind, status, closing?.by, viewer)}
            </p>
            {closedAt && <span className="text-[11px] text-ink-muted">{longWhen(closedAt)}</span>}
          </div>
          {closing?.note && (
            <p className="mt-1.5 text-sm leading-relaxed text-ink">«{closing.note}»</p>
          )}
        </div>
      ) : (
        <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-brand-light/60 pt-3">
          <p className="flex items-center gap-2 text-sm font-bold text-ink">
            <span
              className={`inline-block h-2 w-2 shrink-0 rounded-full ${status === 'completed' ? 'bg-violet-500' : 'bg-brand-accent twinkle'}`}
              aria-hidden
            />
            {nextHint(kind, status, viewer)}
          </p>
          {last && <span className="text-[11px] text-ink-muted">آخر تحديث {shortWhen(last)}</span>}
        </div>
      )}
    </div>
  );
}
