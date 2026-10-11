/**
 * The entrance: two gold curtains that part on the first page of a visit.
 *
 * It is the one moment where the site is allowed to be purely theatrical, and
 * it is over in under two seconds. Three things keep it from being the usual
 * splash-screen mistake:
 *
 *  1. **Once per session.** The flag is set in `sessionStorage` by the inline
 *     script below, which runs in `<head>` — before the browser has painted a
 *     pixel — so on every page after the first the curtain is never shown, not
 *     shown-and-then-hidden.
 *  2. **No JavaScript in the animation itself.** It is CSS keyframes with a
 *     fill mode, so it plays and finishes on its own. The script decides only
 *     whether the element exists.
 *  3. **It cannot strand anyone.** The same script arms a timer that marks the
 *     intro done after 2.2 s no matter what, so a blocked stylesheet or a
 *     browser that never fires the animation still leaves a usable page.
 *
 * The page underneath is fully rendered the whole time — the curtain is an
 * overlay, not a gate — so a crawler, a reader-mode button and a browser with
 * scripting switched off all see the real content.
 */

/* eslint-disable @next/next/no-img-element */

/**
 * Runs in `<head>`, before first paint.
 *
 * Minified by hand rather than by a bundler because it is inlined verbatim
 * into every page and a build step cannot reach it.
 */
export const INTRO_SCRIPT = `(function(){try{var d=document.documentElement;
if(sessionStorage.getItem('afrahna-intro')){d.setAttribute('data-intro','done');return;}
sessionStorage.setItem('afrahna-intro','1');}catch(e){}
setTimeout(function(){document.documentElement.setAttribute('data-intro','done');},2200);})();`;

export default function Intro() {
  return (
    <div className="intro" aria-hidden>
      {/* The two halves of the curtain. Each carries its own grain and a soft
          inner edge, so they read as cloth rather than as two brown boxes. */}
      <div className="grain intro-panel intro-panel-r overflow-hidden">
        <span className="absolute inset-y-0 left-0 w-24 bg-gradient-to-l from-black/20 to-transparent" />
      </div>
      <div className="grain intro-panel intro-panel-l overflow-hidden">
        <span className="absolute inset-y-0 right-0 w-24 bg-gradient-to-r from-black/20 to-transparent" />
      </div>

      {/* The seal, centred over the join. */}
      <div className="absolute inset-0 grid place-items-center">
        <div className="intro-seal flex flex-col items-center gap-4 text-center">
          <span className="relative grid h-28 w-28 place-items-center">
            {/* Two rings turning against each other around the mark. */}
            <svg
              viewBox="0 0 120 120"
              className="spin-slow absolute inset-0 h-full w-full text-cream/70"
              fill="none"
              stroke="currentColor"
            >
              <circle cx="60" cy="60" r="56" strokeWidth="1.2" strokeDasharray="5 8" />
            </svg>
            <svg
              viewBox="0 0 120 120"
              className="spin-rev absolute inset-0 h-full w-full text-cream/45"
              fill="none"
              stroke="currentColor"
            >
              <circle cx="60" cy="60" r="46" strokeWidth="1" strokeDasharray="3 9" />
            </svg>
            <img
              src="/logo.png"
              alt=""
              width={72}
              height={72}
              className="h-[72px] w-[72px] rounded-2xl object-cover shadow-lift"
            />
          </span>

          <span className="text-3xl font-black tracking-wide text-cream">أفراحنا</span>

          {/* A hairline that draws itself under the wordmark. */}
          <span className="intro-line block h-px w-40 origin-center bg-gradient-to-l from-transparent via-cream/80 to-transparent" />

          <span className="text-xs font-bold tracking-[0.3em] text-cream/75">
            كل ما يلزم مناسبتك
          </span>
        </div>
      </div>
    </div>
  );
}
