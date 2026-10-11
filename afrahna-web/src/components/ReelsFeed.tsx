'use client';

/* eslint-disable @next/next/no-img-element */
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { memo, useCallback, useEffect, useRef, useState } from 'react';

import { API_BASE } from '@/lib/api';
import { type Reel, reelsPageUrl, toReel } from '@/lib/reels';
import type { Post } from '@/lib/types';

/**
 * The reels feed — the app's reels tab, in the browser.
 *
 * One video per screen. Swipe (or scroll, or press ↓) and the next one snaps
 * into place and starts playing on its own; the one you left stops. It never
 * ends while there are reels left: three from the bottom, the next page is
 * already on its way.
 *
 * What makes it feel like the app rather than a page of videos:
 *  - **Native scroll-snap**, one reel per swipe (`scroll-snap-stop: always`),
 *    so the finger drives it and a fast flick cannot skip three reels.
 *  - **Only the neighbours exist as videos.** The reel on screen and the next
 *    one load in full, the two either side load their first frame, and every
 *    other reel is just its poster. Three hundred <video> elements would sink
 *    a phone; five do not.
 *  - **Starts muted**, because every browser refuses to autoplay sound — with
 *    a one-tap "sound on" that sticks for the rest of the visit.
 *  - **Tap to pause, double-tap for the heart**, the same gestures as the app.
 *
 * Liking and commenting need an account, which the site does not have, so
 * those buttons say so and point at the app. Reading comments is public, and
 * works here in full.
 */

const SEED_KEY = 'afrahna-reels-seed';
const MUTE_KEY = 'afrahna-reels-muted';

const compact = new Intl.NumberFormat('ar-EG', { notation: 'compact', maximumFractionDigits: 1 });
const fmt = (n: number) => compact.format(n);

interface Toast {
  text: string;
  href?: string;
  cta?: string;
  key: number;
}

export default function ReelsFeed({
  initial,
  hasMore: initialHasMore,
  hrefs,
}: {
  initial: Reel[];
  hasMore: boolean;
  /** Shop id → the shop's real page. Reels carry shops without their slug. */
  hrefs: Record<string, string>;
}) {
  const router = useRouter();
  const scroller = useRef<HTMLDivElement>(null);

  const [reels, setReels] = useState(initial);
  const [active, setActive] = useState(0);
  const [muted, setMuted] = useState(true);
  const [soundHint, setSoundHint] = useState(true);
  /** The reel the reader has paused by tapping it, if any. */
  const [pausedId, setPausedId] = useState<number | null>(null);
  const [tabHidden, setTabHidden] = useState(false);
  const [commentsFor, setCommentsFor] = useState<Reel | null>(null);
  const [toast, setToast] = useState<Toast | null>(null);
  const [hasMore, setHasMore] = useState(initialHasMore);
  const [failed, setFailed] = useState(false);
  /** True while a `?id=` link is fetching the reel it points at. */
  const [holding, setHolding] = useState(false);

  const page = useRef(1);
  const loading = useRef(false);
  const seed = useRef(0);
  const ids = useRef(new Set(initial.map((r) => r.id)));
  const viewed = useRef(new Set<number>());
  // Read by the keyboard handler, which is attached once.
  const activeRef = useRef(0);
  const reelsRef = useRef(initial);
  const mutePersisted = useRef(false);

  useEffect(() => {
    activeRef.current = active;
    reelsRef.current = reels;
  });

  /* ---------------------------------------------------------------- setup */

  // The page behind the feed must not scroll along with it.
  useEffect(() => {
    const html = document.documentElement;
    const before = html.style.overflow;
    html.style.overflow = 'hidden';
    return () => {
      html.style.overflow = before;
    };
  }, []);

  // One shuffle per visit, like the app: the same seed for every page, so the
  // feed neither repeats nor skips while it is being scrolled.
  useEffect(() => {
    const fresh = Math.floor(Math.random() * 0x7ffffffe) + 1;
    try {
      const saved = Number(sessionStorage.getItem(SEED_KEY));
      seed.current = saved > 0 ? saved : fresh;
      sessionStorage.setItem(SEED_KEY, String(seed.current));
      if (sessionStorage.getItem(MUTE_KEY) === '0') setMuted(false);
    } catch {
      seed.current = fresh;
    }
  }, []);

  useEffect(() => {
    // Skip the first run, which would write the default over a saved choice.
    if (!mutePersisted.current) {
      mutePersisted.current = true;
      return;
    }
    try {
      sessionStorage.setItem(MUTE_KEY, muted ? '1' : '0');
    } catch {
      /* private mode: the choice lasts for this page only */
    }
  }, [muted]);

  useEffect(() => {
    const onVisibility = () => setTabHidden(document.hidden);
    document.addEventListener('visibilitychange', onVisibility);
    return () => document.removeEventListener('visibilitychange', onVisibility);
  }, []);

  // Someone who has asked their device for less motion gets the feed paused on
  // each reel, one tap from playing, rather than video starting by itself.
  const [calm, setCalm] = useState(false);
  useEffect(() => {
    setCalm(window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  }, []);
  useEffect(() => {
    if (calm) setPausedId(reelsRef.current[active]?.id ?? null);
  }, [calm, active]);

  useEffect(() => {
    if (!soundHint) return;
    const t = setTimeout(() => setSoundHint(false), 6000);
    return () => clearTimeout(t);
  }, [soundHint]);

  /* ------------------------------------------------------- where we are */

  // The reel on screen, read from the scroll position the browser owns.
  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    let raf = 0;
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        setActive(Math.round(el.scrollTop / (el.clientHeight || 1)));
      });
    };
    el.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      el.removeEventListener('scroll', onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);

  const goTo = useCallback((i: number) => {
    const el = scroller.current;
    if (!el) return;
    const last = reelsRef.current.length; // the closing slide
    const target = Math.max(0, Math.min(i, last));
    el.scrollTo({ top: target * el.clientHeight, behavior: 'smooth' });
  }, []);

  // `/reels?id=123` opens on that reel — how every reel thumbnail elsewhere on
  // the site links in. Declared before the URL sync below, so it reads the
  // address before that effect rewrites it.
  useEffect(() => {
    const id = Number(new URLSearchParams(window.location.search).get('id'));
    if (!id) return;

    const at = initial.findIndex((r) => r.id === id);
    if (at === 0) return;
    if (at > 0) {
      const el = scroller.current;
      if (el) el.scrollTo({ top: at * el.clientHeight });
      setActive(at);
      return;
    }

    // Not in the first page: fetch it and put it first.
    setHolding(true);
    fetch(`${API_BASE}/posts/${id}`, { headers: { Accept: 'application/json' } })
      .then((res) => (res.ok ? res.json() : null))
      .then((body: { data?: Post } | Post | null) => {
        const post = body && 'data' in body && body.data ? body.data : (body as Post | null);
        const reel = post ? toReel(post) : null;
        if (reel && !ids.current.has(reel.id)) {
          ids.current.add(reel.id);
          setReels((prev) => [reel, ...prev]);
        }
      })
      .catch(() => {
        /* the feed simply opens at the top */
      })
      .finally(() => setHolding(false));
  }, [initial]);

  // The address always names the reel on screen, so copying it shares that reel.
  useEffect(() => {
    const r = reels[active];
    if (!r || holding) return;
    window.history.replaceState(window.history.state, '', `${window.location.pathname}?id=${r.id}`);
  }, [active, reels, holding]);

  /* ---------------------------------------------------------- more reels */

  const loadMore = useCallback(async () => {
    if (loading.current || !hasMore) return;
    loading.current = true;
    setFailed(false);
    try {
      // A page made entirely of reels already on screen (a deep-linked one,
      // say) would otherwise end the feed early; ask again, a few times.
      for (let tries = 0; tries < 3; tries++) {
        const res = await fetch(reelsPageUrl(page.current + 1, seed.current), {
          headers: { Accept: 'application/json' },
        });
        if (!res.ok) throw new Error(String(res.status));
        const body = (await res.json()) as { data?: Post[]; current_page?: number; last_page?: number };
        page.current += 1;

        const fresh = (body.data ?? [])
          .map(toReel)
          .filter((r): r is Reel => r !== null && !ids.current.has(r.id));
        fresh.forEach((r) => ids.current.add(r.id));
        if (fresh.length) setReels((prev) => [...prev, ...fresh]);

        const more = (body.current_page ?? 0) < (body.last_page ?? 0);
        setHasMore(more);
        if (fresh.length || !more) break;
      }
    } catch {
      setFailed(true);
    } finally {
      loading.current = false;
    }
  }, [hasMore]);

  useEffect(() => {
    if (active >= reels.length - 3) void loadMore();
  }, [active, reels.length, loadMore]);

  /* --------------------------------------------------------------- views */

  // Counted once per reel per visit, after a second and a half on screen — the
  // same public endpoint the app reports to.
  useEffect(() => {
    const r = reels[active];
    if (!r || holding || viewed.current.has(r.id)) return;
    const t = setTimeout(() => {
      viewed.current.add(r.id);
      fetch(`${API_BASE}/posts/${r.id}/view`, {
        method: 'POST',
        keepalive: true,
        headers: { Accept: 'application/json' },
      }).catch(() => {
        /* never block watching on counting */
      });
    }, 1500);
    return () => clearTimeout(t);
  }, [active, reels, holding]);

  /* ------------------------------------------------------------- actions */

  const say = useCallback((t: Omit<Toast, 'key'>) => setToast({ ...t, key: Date.now() }), []);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 3200);
    return () => clearTimeout(t);
  }, [toast]);

  const toggleMute = useCallback(() => {
    setMuted((m) => !m);
    setSoundHint(false);
  }, []);

  const togglePause = useCallback((id?: number) => {
    const target = id ?? reelsRef.current[activeRef.current]?.id;
    if (target === undefined) return;
    setPausedId((p) => (p === target ? null : target));
  }, []);

  const likePrompt = useCallback(() => {
    say({ text: 'اللايك من تطبيق أفراحنا ❤️', href: '/app', cta: 'حمّل التطبيق' });
  }, [say]);

  const share = useCallback(
    async (r: Reel) => {
      const url = `${window.location.origin}${window.location.pathname}?id=${r.id}`;
      const title = r.vendor ? `${r.vendor.name} على أفراحنا` : 'ريلز أفراحنا';
      try {
        if (navigator.share) {
          await navigator.share({ title, url });
          return;
        }
        await navigator.clipboard.writeText(url);
        say({ text: 'تم نسخ رابط الريل ✓' });
      } catch {
        /* the reader closed the share sheet */
      }
    },
    [say],
  );

  /** Autoplay refused: drop the sound and try again, or wait for a tap. */
  const onBlocked = useCallback((id: number, hadSound: boolean) => {
    if (hadSound) setMuted(true);
    else setPausedId(id);
  }, []);

  const close = useCallback(() => {
    const fromSite = document.referrer.startsWith(window.location.origin);
    if (fromSite && window.history.length > 1) router.back();
    else router.push('/');
  }, [router]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (commentsFor) {
        if (e.key === 'Escape') setCommentsFor(null);
        return;
      }
      const k = e.key;
      if (k === 'ArrowDown' || k === 'PageDown' || k === 'j') {
        e.preventDefault();
        goTo(activeRef.current + 1);
      } else if (k === 'ArrowUp' || k === 'PageUp' || k === 'k') {
        e.preventDefault();
        goTo(activeRef.current - 1);
      } else if (k === ' ') {
        e.preventDefault();
        togglePause();
      } else if (k === 'm' || k === 'M') {
        toggleMute();
      } else if (k === 'Escape') {
        close();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [commentsFor, goTo, togglePause, toggleMute, close]);

  /* -------------------------------------------------------------- render */

  const current = reels[active];
  const sheetOpen = commentsFor !== null;

  return (
    <div className="reels-feed fixed inset-0 z-[60] overflow-hidden bg-black text-white">
      {/* Behind the column on a wide screen: the reel on screen, blurred. */}
      {current?.poster && (
        <img
          key={current.id}
          src={current.poster}
          alt=""
          aria-hidden
          className="pointer-events-none absolute inset-0 h-full w-full scale-110 object-cover opacity-40 blur-3xl"
          style={{ animation: 'fade 0.6s ease both' }}
        />
      )}

      <div
        ref={scroller}
        role="feed"
        aria-label="ريلز"
        aria-busy={holding}
        className="absolute inset-0 snap-y snap-mandatory overflow-y-scroll overscroll-contain
                   [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {reels.map((r, i) => (
          <ReelSlide
            key={r.id}
            reel={r}
            active={i === active}
            near={Math.abs(i - active) <= 2}
            eager={i === active || i === active + 1}
            playing={i === active && !holding && !tabHidden && !sheetOpen && pausedId !== r.id}
            paused={pausedId === r.id}
            muted={muted}
            href={r.vendor ? hrefs[r.vendor.id] : undefined}
            onTogglePause={togglePause}
            onLike={likePrompt}
            onComments={setCommentsFor}
            onShare={share}
            onBlocked={onBlocked}
          />
        ))}

        <TailSlide
          state={
            reels.length === 0 && !hasMore
              ? 'empty'
              : hasMore
                ? failed
                  ? 'failed'
                  : 'loading'
                : 'done'
          }
          onRetry={() => void loadMore()}
          onRestart={() => goTo(0)}
        />
      </div>

      {/* ---- the bar across the top ---- */}
      <div
        className="pointer-events-none absolute inset-x-0 top-0 z-20 flex items-center justify-between
                   bg-gradient-to-b from-black/55 to-transparent px-4 pb-8 pt-[max(env(safe-area-inset-top),0.9rem)]"
      >
        <span className="flex items-center gap-2 text-[22px] font-black [text-shadow:0_1px_8px_rgba(0,0,0,0.6)]">
          <img src="/logo.png" alt="" width={32} height={32} className="h-8 w-8 rounded-lg object-cover" />
          ريلز
        </span>
        <span className="pointer-events-auto flex items-center gap-2">
          <RoundButton label={muted ? 'تشغيل الصوت' : 'كتم الصوت'} onClick={toggleMute}>
            {muted ? <SoundOffIcon /> : <SoundOnIcon />}
          </RoundButton>
          <RoundButton label="إغلاق" onClick={close}>
            <CloseIcon />
          </RoundButton>
        </span>
      </div>

      {/* Every browser starts video silent; this is the one tap that fixes it. */}
      {muted && soundHint && reels.length > 0 && (
        <div className="pointer-events-none absolute inset-x-0 top-[calc(env(safe-area-inset-top)+4.5rem)] z-20 flex justify-center">
          <button
            type="button"
            onClick={toggleMute}
            className="pointer-events-auto flex items-center gap-2 rounded-full bg-black/50 px-4 py-2 text-sm font-bold backdrop-blur-md"
            style={{ animation: 'pop-in 0.6s cubic-bezier(0.34,1.56,0.64,1) 0.4s both' }}
          >
            <SoundOffIcon className="h-4 w-4" />
            اضغط لتشغيل الصوت
          </button>
        </div>
      )}

      {/* Up and down, for a mouse. A phone swipes. */}
      <div className="absolute left-6 top-1/2 z-20 hidden -translate-y-1/2 flex-col gap-3 sm:flex">
        <RoundButton label="الريل السابق" onClick={() => goTo(active - 1)} disabled={active === 0} large>
          <ChevronIcon up />
        </RoundButton>
        <RoundButton label="الريل التالي" onClick={() => goTo(active + 1)} disabled={active >= reels.length} large>
          <ChevronIcon />
        </RoundButton>
      </div>

      {commentsFor && <CommentsSheet reel={commentsFor} onClose={() => setCommentsFor(null)} />}

      {toast && (
        <div
          key={toast.key}
          role="status"
          className="pointer-events-none fixed inset-x-0 bottom-[calc(env(safe-area-inset-bottom)+7.5rem)] z-[75] flex justify-center px-4"
          style={{ animation: 'rise 0.4s cubic-bezier(0.16,1,0.3,1) both' }}
        >
          <div className="pointer-events-auto flex items-center gap-3 rounded-full bg-white/95 py-2 pl-2 pr-4 text-sm font-bold text-ink shadow-2xl">
            {toast.text}
            {toast.href && (
              <Link
                href={toast.href}
                className="rounded-full bg-gradient-to-br from-brand-accent to-brand-dark px-3 py-1.5 text-xs font-black text-white"
              >
                {toast.cta}
              </Link>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

/* ================================================================ one reel */

const ReelSlide = memo(function ReelSlide({
  reel,
  active,
  near,
  eager,
  playing,
  paused,
  muted,
  href,
  onTogglePause,
  onLike,
  onComments,
  onShare,
  onBlocked,
}: {
  reel: Reel;
  active: boolean;
  /** Within two of the reel on screen: worth being a real <video>. */
  near: boolean;
  /** On screen or next: worth loading in full. */
  eager: boolean;
  playing: boolean;
  paused: boolean;
  muted: boolean;
  href?: string;
  onTogglePause: (id: number) => void;
  onLike: () => void;
  onComments: (r: Reel) => void;
  onShare: (r: Reel) => void;
  onBlocked: (id: number, hadSound: boolean) => void;
}) {
  const video = useRef<HTMLVideoElement>(null);
  const frame = useRef<HTMLDivElement>(null);
  const bar = useRef<HTMLSpanElement>(null);
  const tapTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [buffering, setBuffering] = useState(false);
  const [landscape, setLandscape] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [hearts, setHearts] = useState<{ x: number; y: number; key: number }[]>([]);

  // Play the reel on screen; stop every other one.
  useEffect(() => {
    const v = video.current;
    if (!v) return;
    v.muted = muted;
    if (playing) {
      v.play()?.catch((err: DOMException) => {
        if (err?.name === 'NotAllowedError') onBlocked(reel.id, !v.muted);
      });
    } else {
      v.pause();
    }
  }, [playing, muted, near, onBlocked, reel.id]);

  // Leaving a reel rewinds it, so coming back starts it from the top.
  useEffect(() => {
    if (active) return;
    const v = video.current;
    if (v && v.readyState > 0) v.currentTime = 0;
    if (bar.current) bar.current.style.transform = 'scaleX(0)';
    setExpanded(false);
  }, [active]);

  // The progress line, written straight to the DOM each frame while playing —
  // smooth, and no re-render sixty times a second.
  useEffect(() => {
    if (!playing) return;
    let raf = 0;
    const tick = () => {
      const v = video.current;
      const b = bar.current;
      if (v && b && v.duration) b.style.transform = `scaleX(${v.currentTime / v.duration})`;
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [playing]);

  useEffect(
    () => () => {
      if (tapTimer.current) clearTimeout(tapTimer.current);
    },
    [],
  );

  const burst = (x: number, y: number) => {
    const key = Date.now() + Math.random();
    setHearts((h) => [...h, { x, y, key }]);
    setTimeout(() => setHearts((h) => h.filter((p) => p.key !== key)), 950);
  };

  // One tap pauses; two taps inside a quarter of a second are a heart instead.
  const onTap = (e: React.MouseEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - r.left;
    const y = e.clientY - r.top;
    if (tapTimer.current) {
      clearTimeout(tapTimer.current);
      tapTimer.current = null;
      burst(x, y);
      onLike();
      return;
    }
    tapTimer.current = setTimeout(() => {
      tapTimer.current = null;
      onTogglePause(reel.id);
    }, 240);
  };

  const heartFromRail = () => {
    const f = frame.current;
    if (f) burst(f.clientWidth / 2, f.clientHeight / 2);
    onLike();
  };

  const name = reel.vendor?.name ?? 'معلن';
  const long = reel.caption.length > 70 || reel.caption.includes('\n');

  return (
    <article
      aria-label={`ريل من ${name}`}
      className="reel-screen relative flex snap-start snap-always items-center justify-center"
    >
      <div ref={frame} className="reel-frame relative h-full w-full overflow-hidden bg-black sm:shadow-2xl sm:ring-1 sm:ring-white/10">
        {/* A sideways video gets its own poster, blurred, behind the letterbox. */}
        {landscape && reel.poster && (
          <img
            src={reel.poster}
            alt=""
            aria-hidden
            className="absolute inset-0 h-full w-full scale-110 object-cover opacity-60 blur-2xl"
          />
        )}

        {near ? (
          <video
            ref={video}
            src={reel.video}
            poster={reel.poster ?? undefined}
            playsInline
            loop
            muted
            preload={eager ? 'auto' : 'metadata'}
            className={`relative h-full w-full ${landscape ? 'object-contain' : 'object-cover'}`}
            onLoadedMetadata={(e) =>
              setLandscape(e.currentTarget.videoWidth > e.currentTarget.videoHeight)
            }
            onWaiting={() => setBuffering(true)}
            onPlaying={() => setBuffering(false)}
            onCanPlay={() => setBuffering(false)}
          />
        ) : reel.poster ? (
          <img
            src={reel.poster}
            alt=""
            loading="lazy"
            decoding="async"
            className="relative h-full w-full object-cover"
          />
        ) : null}

        <div
          className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/90 via-black/25 via-35% to-transparent to-60%"
          aria-hidden
        />

        {/* The whole picture is the play/pause target. */}
        <div className="absolute inset-0" onClick={onTap} aria-hidden />

        {active && paused && (
          <span className="pointer-events-none absolute inset-0 grid place-items-center" aria-hidden>
            <span
              className="grid h-24 w-24 place-items-center rounded-full bg-black/35 backdrop-blur-sm"
              style={{ animation: 'pop-in 0.35s cubic-bezier(0.34,1.56,0.64,1) both' }}
            >
              <PlayIcon className="h-12 w-12 translate-x-[-2px] text-white/90" />
            </span>
          </span>
        )}

        {active && playing && buffering && (
          <span className="pointer-events-none absolute inset-0 grid place-items-center" aria-hidden>
            <span className="h-11 w-11 animate-spin rounded-full border-[3px] border-white/25 border-t-white" />
          </span>
        )}

        {hearts.map((h) => (
          <span
            key={h.key}
            className="pointer-events-none absolute z-20"
            style={{ left: h.x, top: h.y, animation: 'heart-burst 0.95s cubic-bezier(0.16,1,0.3,1) both' }}
            aria-hidden
          >
            <HeartIcon filled className="h-24 w-24 text-[#FF3B5C] drop-shadow-[0_6px_24px_rgba(255,59,92,0.6)]" />
          </span>
        ))}

        {/* ---- the side rail (left, as in the app's RTL layout) ---- */}
        <div className="pointer-events-none absolute bottom-[calc(env(safe-area-inset-bottom)+1.75rem)] left-2.5 z-10 flex flex-col items-center gap-4">
          {reel.vendor && (
            <MaybeLink href={href} label={`صفحة ${name}`} className="pointer-events-auto mb-1 block">
              <span className="relative block">
                <span className="grid h-12 w-12 place-items-center overflow-hidden rounded-full border-2 border-white bg-white/20">
                  {reel.vendor.logo ? (
                    <img src={reel.vendor.logo} alt="" loading="lazy" className="h-full w-full object-cover" />
                  ) : (
                    <StoreIcon />
                  )}
                </span>
                <span className="absolute -bottom-2 left-1/2 grid h-5 w-5 -translate-x-1/2 place-items-center rounded-full bg-gradient-to-br from-brand-accent to-brand-dark text-white">
                  <PlusIcon />
                </span>
              </span>
            </MaybeLink>
          )}

          <RailButton label="لايك" count={reel.likes} onClick={heartFromRail}>
            <HeartIcon className="h-7 w-7" />
          </RailButton>
          <RailButton label="التعليقات" count={reel.comments} onClick={() => onComments(reel)}>
            <CommentIcon />
          </RailButton>
          <span className="flex flex-col items-center gap-1 text-[11px] font-bold [text-shadow:0_1px_6px_rgba(0,0,0,0.8)]">
            <span className="grid h-11 w-11 place-items-center">
              <EyeIcon />
            </span>
            <span suppressHydrationWarning>{fmt(reel.views)}</span>
            <span className="sr-only">مشاهدة</span>
          </span>
          <RailButton label="مشاركة" onClick={() => onShare(reel)}>
            <ShareIcon />
          </RailButton>
        </div>

        {/* ---- the shop and the caption ---- */}
        <div className="pointer-events-none absolute bottom-[calc(env(safe-area-inset-bottom)+1.75rem)] left-20 right-4 z-10 text-right">
          {reel.vendor && (
            <MaybeLink href={href} className="pointer-events-auto inline-flex max-w-full items-center gap-2">
              <span className="truncate text-[17px] font-black [text-shadow:0_1px_8px_rgba(0,0,0,0.85)]">
                {name}
              </span>
              {href && (
                <span className="shrink-0 rounded-md border-[1.4px] border-white px-3 py-0.5 text-xs font-bold">
                  زيارة
                </span>
              )}
            </MaybeLink>
          )}

          {reel.caption && (
            <button
              type="button"
              onClick={() => long && setExpanded((x) => !x)}
              className={`mt-2 block w-full text-right ${long ? 'pointer-events-auto' : ''}`}
            >
              <span
                className={`block whitespace-pre-line text-[14.5px] leading-snug [text-shadow:0_1px_6px_rgba(0,0,0,0.85)] ${
                  expanded ? 'max-h-48 overflow-y-auto' : 'line-clamp-2'
                }`}
              >
                {reel.caption}
              </span>
              {long && (
                <span className="mt-0.5 block text-[13px] font-bold text-white/70">
                  {expanded ? 'إخفاء' : 'المزيد'}
                </span>
              )}
            </button>
          )}

          <p className="mt-2.5 flex items-center gap-1.5 text-[13px] font-semibold [text-shadow:0_1px_5px_rgba(0,0,0,0.85)]">
            <MusicIcon />
            <span className="truncate">الصوت الأصلي · {name}</span>
          </p>
        </div>

        {/* How far through this reel you are. */}
        <span className="pointer-events-none absolute inset-x-0 bottom-0 z-10 h-[3px] bg-white/20" aria-hidden>
          <span ref={bar} className="block h-full origin-right bg-white" style={{ transform: 'scaleX(0)' }} />
        </span>
      </div>
    </article>
  );
});

/** The screen after the last reel: loading, a retry, or the end. */
function TailSlide({
  state,
  onRetry,
  onRestart,
}: {
  state: 'loading' | 'failed' | 'done' | 'empty';
  onRetry: () => void;
  onRestart: () => void;
}) {
  return (
    <div className="reel-screen relative flex snap-start snap-always flex-col items-center justify-center gap-4 px-6 text-center">
      {state === 'loading' && (
        <span className="h-11 w-11 animate-spin rounded-full border-[3px] border-white/25 border-t-white" aria-label="جاري التحميل" />
      )}
      {state === 'failed' && (
        <>
          <p className="text-lg font-black">ما قدرنا نجيب ريلز جديدة</p>
          <button type="button" onClick={onRetry} className="btn-primary">
            جرّب مرة ثانية
          </button>
        </>
      )}
      {(state === 'done' || state === 'empty') && (
        <>
          <span className="text-5xl" aria-hidden>
            {state === 'done' ? '🎉' : '🎬'}
          </span>
          <p className="text-xl font-black">{state === 'done' ? 'شفت كل الريلز!' : 'لا توجد فيديوهات الآن'}</p>
          <p className="max-w-xs text-sm text-white/70">
            {state === 'done'
              ? 'رجعنا نضيف جديد كل يوم — تابع المحلات من التطبيق عشان يوصلك أول بأول.'
              : 'تابعنا — المحلات بتنشر شغلها هون أول بأول.'}
          </p>
          <div className="mt-2 flex flex-wrap justify-center gap-3">
            {state === 'done' && (
              <button type="button" onClick={onRestart} className="btn-primary">
                من الأول ↑
              </button>
            )}
            <Link href="/vendors" className="btn border border-white/40 text-white hover:bg-white/10">
              تصفّح المحلات
            </Link>
          </div>
        </>
      )}
    </div>
  );
}

/* ============================================================== comments */

interface ReelComment {
  id: number;
  body?: string | null;
  guest_name?: string | null;
  user?: { name?: string | null } | null;
  created_at?: string | null;
}

const relative = new Intl.RelativeTimeFormat('ar', { numeric: 'auto' });

function ago(iso?: string | null): string {
  if (!iso) return '';
  const s = (new Date(iso).getTime() - Date.now()) / 1000;
  if (!Number.isFinite(s)) return '';
  const a = Math.abs(s);
  if (a < 60) return relative.format(Math.round(s), 'second');
  if (a < 3600) return relative.format(Math.round(s / 60), 'minute');
  if (a < 86400) return relative.format(Math.round(s / 3600), 'hour');
  if (a < 2592000) return relative.format(Math.round(s / 86400), 'day');
  if (a < 31536000) return relative.format(Math.round(s / 2592000), 'month');
  return relative.format(Math.round(s / 31536000), 'year');
}

/**
 * The comments, read-only, in a sheet that rises from the bottom as it does in
 * the app. The reel pauses behind it and picks up again when it closes.
 */
function CommentsSheet({ reel, onClose }: { reel: Reel; onClose: () => void }) {
  const [items, setItems] = useState<ReelComment[] | null>(null);
  const [failed, setFailed] = useState(false);
  const closeBtn = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    closeBtn.current?.focus();
  }, []);

  useEffect(() => {
    let alive = true;
    fetch(`${API_BASE}/posts/${reel.id}/comments?per_page=30`, { headers: { Accept: 'application/json' } })
      .then((res) => {
        if (!res.ok) throw new Error(String(res.status));
        return res.json();
      })
      .then((body: { data?: ReelComment[] } | ReelComment[]) => {
        if (alive) setItems(Array.isArray(body) ? body : (body.data ?? []));
      })
      .catch(() => {
        if (alive) setFailed(true);
      });
    return () => {
      alive = false;
    };
  }, [reel.id]);

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center" role="dialog" aria-modal="true" aria-label="التعليقات">
      <button
        type="button"
        aria-label="إغلاق التعليقات"
        onClick={onClose}
        className="absolute inset-0 cursor-default bg-black/50"
        style={{ animation: 'fade 0.25s ease both' }}
      />

      <div
        className="relative flex max-h-[72vh] w-full flex-col rounded-t-[1.75rem] bg-cream-surface text-ink shadow-2xl
                   sm:mb-6 sm:w-[440px] sm:rounded-[1.75rem]"
        style={{ animation: 'sheet-up 0.45s cubic-bezier(0.16,1,0.3,1) both' }}
      >
        <span className="mx-auto mt-3 h-1.5 w-12 rounded-full bg-brand-light" aria-hidden />

        <header className="flex items-center justify-between px-5 pb-3 pt-3">
          <h2 className="text-lg font-black">
            التعليقات{' '}
            <span className="text-sm text-ink-muted" suppressHydrationWarning>
              ({fmt(reel.comments)})
            </span>
          </h2>
          <button
            ref={closeBtn}
            type="button"
            onClick={onClose}
            aria-label="إغلاق"
            className="grid h-9 w-9 place-items-center rounded-full bg-brand-light/60 text-brand-dark transition-transform hover:scale-105"
          >
            <CloseIcon className="h-4 w-4" />
          </button>
        </header>

        <div className="min-h-[9rem] flex-1 overflow-y-auto overscroll-contain px-5 pb-4">
          {items === null && !failed && (
            <ul className="space-y-4" aria-label="جاري التحميل">
              {[0, 1, 2].map((k) => (
                <li key={k} className="flex gap-3">
                  <span className="skeleton h-9 w-9 shrink-0 rounded-full" />
                  <span className="flex-1 space-y-2">
                    <span className="skeleton block h-3 w-24 rounded" />
                    <span className="skeleton block h-3 w-3/4 rounded" />
                  </span>
                </li>
              ))}
            </ul>
          )}

          {failed && <p className="py-8 text-center text-sm text-ink-muted">ما قدرنا نجيب التعليقات هلّق.</p>}

          {items?.length === 0 && (
            <p className="py-8 text-center text-sm text-ink-muted">لسا ما في تعليقات — كن أول واحد من التطبيق.</p>
          )}

          {items && items.length > 0 && (
            <ul className="space-y-4">
              {items.map((c, i) => {
                const who = (c.user?.name || c.guest_name || 'زائر').trim();
                return (
                  <li
                    key={c.id}
                    className="flex gap-3"
                    style={{ animation: `rise 0.5s cubic-bezier(0.16,1,0.3,1) ${Math.min(i, 8) * 40}ms both` }}
                  >
                    <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-gradient-to-br from-brand-accent to-brand-dark text-sm font-black text-white">
                      {Array.from(who)[0]}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-baseline gap-2">
                        <span className="truncate text-sm font-black">{who}</span>
                        <span className="shrink-0 text-[11px] text-ink-muted">{ago(c.created_at)}</span>
                      </span>
                      <span className="mt-0.5 block whitespace-pre-line break-words text-sm leading-relaxed text-ink">
                        {c.body}
                      </span>
                    </span>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <footer className="border-t border-brand-light p-4 pb-[max(env(safe-area-inset-bottom),1rem)]">
          <Link href="/app" className="btn-primary w-full">
            اكتب تعليقك من تطبيق أفراحنا
          </Link>
        </footer>
      </div>
    </div>
  );
}

/* ================================================================= bits */

function MaybeLink({
  href,
  label,
  className,
  children,
}: {
  href?: string;
  label?: string;
  className?: string;
  children: React.ReactNode;
}) {
  if (!href) return <span className={className}>{children}</span>;
  return (
    <Link href={href} aria-label={label} className={className}>
      {children}
    </Link>
  );
}

function RailButton({
  label,
  count,
  onClick,
  children,
}: {
  label: string;
  count?: number;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="pointer-events-auto flex flex-col items-center gap-1 text-[11px] font-bold [text-shadow:0_1px_6px_rgba(0,0,0,0.8)]"
    >
      <span className="grid h-11 w-11 place-items-center rounded-full transition-transform duration-300 ease-[cubic-bezier(0.34,1.56,0.64,1)] hover:scale-110 active:scale-90">
        {children}
      </span>
      <span suppressHydrationWarning>{count === undefined ? label : fmt(count)}</span>
    </button>
  );
}

function RoundButton({
  label,
  onClick,
  disabled,
  large,
  children,
}: {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  large?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      className={`grid place-items-center rounded-full border border-white/20 bg-white/15 text-white backdrop-blur-md
                  transition-all duration-300 hover:scale-105 hover:bg-white/25 disabled:pointer-events-none disabled:opacity-30
                  ${large ? 'h-12 w-12' : 'h-10 w-10'}`}
    >
      {children}
    </button>
  );
}

type IconProps = { className?: string };

function HeartIcon({ filled, className = '' }: IconProps & { filled?: boolean }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill={filled ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={filled ? 0 : 2} aria-hidden>
      <path d="M12 21s-7.5-4.6-9.6-9.2C.9 8.4 3 4.5 6.7 4.5c2.1 0 3.6 1.2 5.3 3.2 1.7-2 3.2-3.2 5.3-3.2 3.7 0 5.8 3.9 4.3 7.3C19.5 16.4 12 21 12 21Z" strokeLinejoin="round" />
    </svg>
  );
}

function CommentIcon({ className = 'h-7 w-7' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden>
      <path d="M20.5 11.5a8 8 0 0 1-11.9 7L3.5 20l1.5-4.6A8 8 0 1 1 20.5 11.5Z" />
    </svg>
  );
}

function EyeIcon({ className = 'h-7 w-7' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z" strokeLinejoin="round" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

function ShareIcon({ className = 'h-7 w-7' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M21 3 10 14M21 3l-7 18-4-7-7-4 18-7Z" />
    </svg>
  );
}

function PlayIcon({ className = '' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor" aria-hidden>
      <path d="M8 5.1v13.8c0 .8.9 1.3 1.6.9l10.8-6.9c.6-.4.6-1.3 0-1.7L9.6 4.2C8.9 3.8 8 4.3 8 5.1Z" />
    </svg>
  );
}

function SoundOnIcon({ className = 'h-5 w-5' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M11 5 6 9H2v6h4l5 4V5Z" />
      <path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14" />
    </svg>
  );
}

function SoundOffIcon({ className = 'h-5 w-5' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M11 5 6 9H2v6h4l5 4V5Z" />
      <path d="m22 9-6 6M16 9l6 6" />
    </svg>
  );
}

function CloseIcon({ className = 'h-5 w-5' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden>
      <path d="M18 6 6 18M6 6l12 12" />
    </svg>
  );
}

function ChevronIcon({ up, className = 'h-6 w-6' }: IconProps & { up?: boolean }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d={up ? 'm6 15 6-6 6 6' : 'm6 9 6 6 6-6'} />
    </svg>
  );
}

function PlusIcon({ className = 'h-3 w-3' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" aria-hidden>
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

function MusicIcon({ className = 'h-4 w-4 shrink-0' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor" aria-hidden>
      <path d="M9 17.5V6.6c0-.5.3-.9.8-1l9-2.1c.6-.1 1.2.3 1.2 1v11a3 3 0 1 1-2-2.8V7.3l-7 1.6v8.6a3 3 0 1 1-2-2.8" />
    </svg>
  );
}

function StoreIcon({ className = 'h-6 w-6' }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden>
      <path d="M4 9.5 5.5 4h13L20 9.5M4 9.5V20h16V9.5M4 9.5h16M9.5 20v-5h5v5" />
    </svg>
  );
}
