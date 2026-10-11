'use client';

import Link from 'next/link';
import { useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { createPortal } from 'react-dom';

// ---------------------------------------------------------------------------
// Toasts
// ---------------------------------------------------------------------------

export type ToastTone = 'success' | 'error' | 'info' | 'notice';

interface Toast {
  id: number;
  tone: ToastTone;
  title: string;
  body?: string;
  href?: string | null;
}

let toasts: Toast[] = [];
let nextId = 1;
const listeners = new Set<() => void>();

function emit() {
  for (const l of listeners) l();
}

/** Shows a message at the edge of the screen for a few seconds. */
export function toast(
  title: string,
  opts: { tone?: ToastTone; body?: string; href?: string | null; ms?: number } = {},
): void {
  const id = nextId++;
  toasts = [...toasts.slice(-3), { id, tone: opts.tone ?? 'success', title, body: opts.body, href: opts.href }];
  emit();
  window.setTimeout(() => dismiss(id), opts.ms ?? (opts.tone === 'notice' ? 9000 : 4200));
}

function dismiss(id: number) {
  toasts = toasts.filter((t) => t.id !== id);
  emit();
}

const EMPTY: Toast[] = [];

/** Where toasts appear. Mounted once, in the layout. */
export function Toaster() {
  const list = useSyncExternalStore(
    (cb) => {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
    () => toasts,
    () => EMPTY,
  );

  return (
    <div
      className="pointer-events-none fixed inset-x-0 top-20 z-[80] flex flex-col items-center gap-2 px-4
                 sm:inset-x-auto sm:left-6 sm:items-start"
      aria-live="polite"
    >
      {list.map((t) => {
        const tone = {
          success: 'border-emerald-200 text-emerald-700',
          error: 'border-red-200 text-sale',
          info: 'border-brand-light text-brand-dark',
          notice: 'border-brand-accent/60 text-brand-dark',
        }[t.tone];
        const icon = { success: '✓', error: '!', info: 'i', notice: '🔔' }[t.tone];
        const inner = (
          <>
            <span
              className={`grid h-8 w-8 shrink-0 place-items-center rounded-full border bg-white text-sm font-black ${tone}`}
              aria-hidden
            >
              {icon}
            </span>
            <span className="min-w-0 flex-1">
              <span className="block text-sm font-black text-ink">{t.title}</span>
              {t.body && <span className="mt-0.5 block text-xs leading-relaxed text-ink-muted">{t.body}</span>}
            </span>
          </>
        );
        const cls = `pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-2xl border bg-white/95 p-3
                     shadow-lift backdrop-blur-xl ${tone}`;
        return (
          <div key={t.id} style={{ animation: 'pop-in 0.45s cubic-bezier(0.34,1.56,0.64,1) both' }} className="w-full max-w-sm">
            {t.href ? (
              <Link href={t.href} className={cls} onClick={() => dismiss(t.id)}>
                {inner}
              </Link>
            ) : (
              <button type="button" className={`${cls} text-right`} onClick={() => dismiss(t.id)}>
                {inner}
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Modal
// ---------------------------------------------------------------------------

/**
 * A dialog: a sheet from the bottom on a phone, a card in the middle from a
 * tablet up. Escape and the backdrop close it; focus moves into it on open.
 *
 * Rendered into <body> through a portal: every page plays its entrance inside
 * a transformed wrapper, and a transformed ancestor makes `position: fixed`
 * relative to that wrapper — the backdrop covered the page while the dialog
 * itself sat somewhere far below the screen.
 */
export function Modal({
  open,
  onClose,
  title,
  children,
  wide = false,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  wide?: boolean;
}) {
  const box = useRef<HTMLDivElement>(null);
  // Held in a ref: callers pass a fresh arrow on every render, and depending
  // on it re-ran this effect on each keystroke, pulling focus back to the
  // first field while the visitor typed in another.
  const close = useRef(onClose);
  close.current = onClose;

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close.current();
    };
    window.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    box.current?.querySelector<HTMLElement>('input, select, textarea, button')?.focus();
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = prev;
    };
  }, [open]);

  if (!open || typeof document === 'undefined') return null;

  return createPortal(
    <div className="fixed inset-0 z-[90] flex items-end justify-center sm:items-center" role="dialog" aria-modal aria-label={title}>
      <button
        type="button"
        className="absolute inset-0 bg-ink/40 backdrop-blur-sm"
        style={{ animation: 'fade 0.3s ease both' }}
        onClick={onClose}
        aria-label="إغلاق"
      />
      <div
        ref={box}
        className={`relative max-h-[92dvh] w-full overflow-y-auto rounded-t-[28px] bg-cream-surface p-5 shadow-lift
                    sm:rounded-[28px] sm:p-7 ${wide ? 'sm:max-w-2xl' : 'sm:max-w-lg'}`}
        style={{ animation: 'sheet-up 0.45s cubic-bezier(0.16,1,0.3,1) both' }}
      >
        <span
          className="pointer-events-none absolute inset-x-10 top-0 h-px bg-gradient-to-l from-transparent via-brand-accent to-transparent"
          aria-hidden
        />
        <div className="mb-4 flex items-center justify-between gap-3">
          <h2 className="text-lg font-black text-ink">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="grid h-9 w-9 place-items-center rounded-full border border-brand-light bg-white text-ink-muted
                       transition-colors hover:border-brand hover:text-brand-dark"
            aria-label="إغلاق"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>,
    document.body,
  );
}

/**
 * Asks for an optional reason before a rejection or a cancellation — the
 * words reach the other side as they are written.
 */
export function ReasonDialog({
  open,
  title,
  message,
  confirm,
  placeholder,
  busy,
  onCancel,
  onConfirm,
}: {
  open: boolean;
  title: string;
  message: string;
  confirm: string;
  placeholder: string;
  busy?: boolean;
  onCancel: () => void;
  onConfirm: (reason: string) => void;
}) {
  const [reason, setReason] = useState('');

  useEffect(() => {
    if (open) setReason('');
  }, [open]);

  return (
    <Modal open={open} onClose={onCancel} title={title}>
      <p className="text-sm leading-relaxed text-ink-muted">{message}</p>
      <label className="mt-4 block">
        <span className="mb-1.5 block text-xs font-black text-ink">السبب (اختياري)</span>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value.slice(0, 300))}
          rows={3}
          placeholder={placeholder}
          className="field resize-none"
        />
      </label>
      <div className="mt-5 flex gap-3">
        <button type="button" onClick={onCancel} className="btn-ghost flex-1">
          تراجع
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => onConfirm(reason)}
          className="btn flex-1 bg-sale text-white shadow-[0_8px_20px_rgba(193,69,43,0.3)] disabled:opacity-60"
        >
          {busy ? 'لحظة…' : confirm}
        </button>
      </div>
    </Modal>
  );
}

/** A small spinning ring for buttons and loading states. */
export function Spinner({ className = 'h-5 w-5' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={`animate-spin ${className}`} fill="none" aria-hidden>
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeOpacity="0.25" strokeWidth="3" />
      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
    </svg>
  );
}
