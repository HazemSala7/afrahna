'use client';

import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useState } from 'react';

import { errorMessage } from '@/lib/client-api';
import { useSession } from '@/lib/session';

import { Spinner } from './feedback';

/** Only paths on this site — never an address someone slipped into the link. */
function safeNext(raw: string | null): string {
  if (!raw || !raw.startsWith('/') || raw.startsWith('//')) return '/account';
  return raw;
}

/**
 * Signing in and signing up, with the same account as the app: whoever has
 * booked from their phone finds the same bookings here.
 */
export default function LoginForm() {
  const params = useSearchParams();
  const router = useRouter();
  const { ready, signedIn, login, register } = useSession();

  const [mode, setMode] = useState<'login' | 'register'>(
    params.get('mode') === 'register' ? 'register' : 'login',
  );
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const next = safeNext(params.get('next'));

  useEffect(() => {
    if (ready && signedIn) router.replace(next);
  }, [ready, signedIn, next, router]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    const digits = phone.replace(/[^\d+]/g, '');
    if (digits.replace(/\D/g, '').length < 7) {
      setError('أدخل رقم جوال صحيح');
      return;
    }
    if (mode === 'register' && name.trim().length < 2) {
      setError('أدخل اسمك الكامل');
      return;
    }
    if (password.length < (mode === 'register' ? 6 : 1)) {
      setError(mode === 'register' ? 'كلمة المرور ٦ أحرف على الأقل' : 'أدخل كلمة المرور');
      return;
    }
    setBusy(true);
    try {
      if (mode === 'login') await login(digits, password);
      else await register({ name: name.trim(), phone: digits, password });
      router.replace(next);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  return (
    <div className="card grain relative mx-auto w-full max-w-md overflow-hidden p-6 sm:p-8">
      <span
        className="pointer-events-none absolute inset-x-10 top-0 h-px bg-gradient-to-l from-transparent via-brand-accent to-transparent"
        aria-hidden
      />
      <div className="mb-6 grid grid-cols-2 rounded-2xl border border-brand-light bg-cream p-1" role="tablist">
        {(['login', 'register'] as const).map((m) => (
          <button
            key={m}
            type="button"
            role="tab"
            aria-selected={mode === m}
            onClick={() => {
              setMode(m);
              setError(null);
            }}
            className={`rounded-xl py-2.5 text-sm font-black transition-all ${
              mode === m
                ? 'bg-white text-brand-dark shadow-card'
                : 'text-ink-muted hover:text-brand-dark'
            }`}
          >
            {m === 'login' ? 'تسجيل الدخول' : 'حساب جديد'}
          </button>
        ))}
      </div>

      <form onSubmit={submit} className="grid gap-4" noValidate>
        {mode === 'register' && (
          <label className="block">
            <span className="mb-1.5 block text-xs font-black text-ink">الاسم الكامل</span>
            <input value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" className="field" />
          </label>
        )}
        <label className="block">
          <span className="mb-1.5 block text-xs font-black text-ink">رقم الجوال</span>
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            inputMode="tel"
            autoComplete="tel"
            dir="ltr"
            placeholder="05XXXXXXXX"
            className="field text-left"
          />
        </label>
        <label className="block">
          <span className="mb-1.5 block text-xs font-black text-ink">كلمة المرور</span>
          <span className="relative block">
            <input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              type={show ? 'text' : 'password'}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              className="field pl-16"
            />
            <button
              type="button"
              onClick={() => setShow((s) => !s)}
              className="absolute left-2 top-1/2 -translate-y-1/2 rounded-lg px-2 py-1 text-xs font-bold text-brand-dark hover:bg-cream"
            >
              {show ? 'إخفاء' : 'إظهار'}
            </button>
          </span>
        </label>

        {error && (
          <p className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-bold text-sale" role="alert">
            {error}
          </p>
        )}

        <button type="submit" disabled={busy} className="btn-primary mt-1 !py-3.5 disabled:opacity-60">
          {busy ? <Spinner /> : mode === 'login' ? 'دخول' : 'إنشاء الحساب'}
        </button>
      </form>

      <p className="mt-5 text-center text-xs leading-relaxed text-ink-muted">
        نفس حسابك في تطبيق أفراحنا — حجوزاتك وطلباتك وإشعاراتك في المكانين.
        {mode === 'login' && (
          <>
            {' '}نسيت كلمة المرور؟{' '}
            <Link href="/contact" className="font-bold text-brand-dark hover:underline">تواصل معنا</Link>
          </>
        )}
      </p>
    </div>
  );
}
