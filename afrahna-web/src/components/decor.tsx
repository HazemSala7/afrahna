/**
 * The decorative layer: the things that make a page feel *made* rather than
 * generated — falling petals, rising candlelight, gold ornament, bunting.
 *
 * All of it is server-rendered SVG and CSS. None of it ships a byte of
 * JavaScript, and none of it is interactive, so every piece is `aria-hidden`
 * and `pointer-events-none`: it is atmosphere, and atmosphere must never eat a
 * tap meant for the card underneath.
 *
 * Every random-looking value is derived from the index instead of Math.random,
 * so the server and the browser render the same thing and React never
 * complains about a hydration mismatch.
 */

/* ---------------------------------------------------------------- backdrop */

/** Soft drifting colour behind a section. Purely atmosphere. */
export function Aurora() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      <span
        className="aurora"
        style={{
          inset: '-18% 45% 55% -12%',
          background: 'rgba(212,163,115,0.45)',
          animationDelay: '0s',
        }}
      />
      <span
        className="aurora"
        style={{
          inset: '35% -14% -22% 48%',
          background: 'rgba(217,133,123,0.34)',
          animationDelay: '-7s',
        }}
      />
      <span
        className="aurora"
        style={{
          inset: '-10% -8% 60% 55%',
          background: 'rgba(240,221,200,0.65)',
          animationDelay: '-14s',
        }}
      />
    </div>
  );
}

/**
 * Petals falling past the hero.
 *
 * Each is an SVG shape with its own delay, duration and drift, so the fall
 * never visibly repeats. Fourteen is the number where it reads as atmosphere;
 * past twenty-five it reads as weather.
 */
export function Petals({ count = 14 }: { count?: number }) {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      {Array.from({ length: count }, (_, i) => {
        const left = (i * 37) % 100;
        const size = 9 + ((i * 13) % 12);
        const delay = -(i * 2.4);
        const duration = 14 + ((i * 7) % 11);
        const drift = (i % 2 ? 1 : -1) * (24 + ((i * 11) % 46));
        return (
          <svg
            key={i}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            className="absolute top-0"
            style={{
              left: `${left}%`,
              ['--drift' as string]: `${drift}px`,
              animation: `fall ${duration}s linear ${delay}s infinite`,
              color: i % 3 === 0 ? '#E8C9A0' : i % 3 === 1 ? '#EBBDB4' : '#D4A373',
            }}
          >
            <path
              d="M12 2c3.5 3 6 6 6 9a6 6 0 1 1-12 0c0-3 2.5-6 6-9Z"
              fill="currentColor"
              opacity="0.75"
            />
          </svg>
        );
      })}
    </div>
  );
}

/**
 * Warm lights rising slowly through a section.
 *
 * The single cheapest way to make a page feel like an evening rather than a
 * screen: soft out-of-focus circles the colour of candlelight, drifting up.
 * Blurred once at paint and then only translated, so they cost nothing to
 * keep moving.
 */
export function Bokeh({
  count = 16,
  /** How far up they travel. Match it to the height of the section. */
  rise = '-108vh',
}: {
  count?: number;
  rise?: string;
}) {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      {Array.from({ length: count }, (_, i) => {
        const left = (i * 61) % 100;
        const size = 8 + ((i * 17) % 34);
        const duration = 18 + ((i * 5) % 16);
        const delay = -(i * 2.9);
        const drift = (i % 2 ? 1 : -1) * (18 + ((i * 23) % 54));
        const opacity = 0.22 + ((i * 7) % 30) / 100;
        return (
          <span
            key={i}
            className="absolute bottom-0 rounded-full"
            style={{
              left: `${left}%`,
              width: size,
              height: size,
              background:
                i % 4 === 0
                  ? 'radial-gradient(circle, rgba(255,241,214,0.95), rgba(212,163,115,0))'
                  : 'radial-gradient(circle, rgba(240,221,200,0.9), rgba(184,131,90,0))',
              filter: 'blur(1px)',
              ['--o' as string]: `${opacity}`,
              ['--drift' as string]: `${drift}px`,
              ['--rise' as string]: rise,
              animation: `bokeh-rise ${duration}s linear ${delay}s infinite`,
            }}
          />
        );
      })}
    </div>
  );
}

/**
 * Gold stars that catch the light and let it go.
 *
 * Placed on a coarse grid rather than at random so they never clump into a
 * blob in one corner, and staggered so no two flash together.
 */
export function Sparkles({ count = 18 }: { count?: number }) {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      {Array.from({ length: count }, (_, i) => {
        const left = 4 + ((i * 29) % 92);
        const top = 6 + ((i * 47) % 88);
        const size = 7 + ((i * 11) % 12);
        const delay = ((i * 13) % 40) / 10;
        const duration = 2.6 + ((i * 7) % 22) / 10;
        return (
          <svg
            key={i}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            className="absolute text-brand-accent"
            style={{
              left: `${left}%`,
              top: `${top}%`,
              animation: `sparkle ${duration}s ease-in-out ${delay}s infinite`,
            }}
          >
            {/* A four-point star: the shape a highlight actually makes. */}
            <path
              d="M12 0c.6 6.6 4.8 10.8 12 12-7.2 1.2-11.4 5.4-12 12-.6-6.6-4.8-10.8-12-12C7.2 10.8 11.4 6.6 12 0Z"
              fill="currentColor"
            />
          </svg>
        );
      })}
    </div>
  );
}

/**
 * Confetti over a band of colour.
 *
 * Falls faster than a petal and tumbles on two axes, which is what separates
 * paper from a leaf. Kept to the celebratory bands so the whole site is not
 * permanently at the moment the cake is cut.
 */
export function Confetti({
  count = 22,
  /** How far it falls. Match it to the height of the band. */
  drop = '112vh',
}: {
  count?: number;
  drop?: string;
}) {
  const colours = ['#D4A373', '#E8C9A0', '#EBBDB4', '#F3E5D2', '#B8835A', '#FFFFFF'];
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      {Array.from({ length: count }, (_, i) => {
        const left = (i * 43) % 100;
        const w = 5 + ((i * 7) % 6);
        const h = w * (i % 3 === 0 ? 1 : 1.9);
        const duration = 6 + ((i * 11) % 9);
        const delay = -((i * 17) % 90) / 10;
        const drift = (i % 2 ? 1 : -1) * (20 + ((i * 31) % 70));
        return (
          <span
            key={i}
            className="absolute top-0 block"
            style={{
              left: `${left}%`,
              width: w,
              height: h,
              background: colours[i % colours.length],
              borderRadius: i % 3 === 0 ? '50%' : '1px',
              opacity: 0.85,
              ['--drift' as string]: `${drift}px`,
              ['--drop' as string]: drop,
              animation: `confetti ${duration}s linear ${delay}s infinite`,
            }}
          />
        );
      })}
    </div>
  );
}

/* --------------------------------------------------------------- ornaments */

/** A small gold flourish, for section breaks and above headings. */
export function Flourish({ className = '' }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 160 16"
      className={`h-4 text-brand ${className}`}
      fill="none"
      stroke="currentColor"
      strokeWidth="1.3"
      aria-hidden
    >
      <path d="M2 8h48M110 8h48" strokeLinecap="round" opacity="0.55" />
      <path d="M60 8c6-6 12-6 20 0s14 6 20 0" strokeLinecap="round" />
      <circle cx="80" cy="8" r="2.6" fill="currentColor" stroke="none" />
      <circle cx="54" cy="8" r="1.4" fill="currentColor" stroke="none" opacity="0.7" />
      <circle cx="106" cy="8" r="1.4" fill="currentColor" stroke="none" opacity="0.7" />
    </svg>
  );
}

/**
 * A gold rule that draws itself across the page, with a turning rosette at the
 * centre.
 *
 * The stroke is dashed by exactly its own length and the dash offset animates
 * to zero, which is how an SVG line draws rather than fades. Put one between
 * two sections and the page stops being a stack of boxes.
 */
export function GoldDivider({ className = '' }: { className?: string }) {
  const line = {
    strokeDasharray: 300,
    strokeDashoffset: 300,
    animation: 'draw 1.6s cubic-bezier(0.16,1,0.3,1) both',
  } as const;

  return (
    <div className={`flex items-center justify-center gap-4 ${className}`} aria-hidden>
      <svg viewBox="0 0 300 8" className="h-2 max-w-[38%] flex-1 text-brand/50" fill="none">
        <path
          d="M300 4H0"
          stroke="url(#gd-a)"
          strokeWidth="1.5"
          strokeLinecap="round"
          style={line}
        />
        <defs>
          <linearGradient id="gd-a" x1="300" y1="0" x2="0" y2="0">
            <stop stopColor="#8B5A3C" />
            <stop offset="1" stopColor="#D4A373" stopOpacity="0" />
          </linearGradient>
        </defs>
      </svg>

      {/* The rosette: two rings turning against each other, plus a still core. */}
      <span className="relative grid h-9 w-9 shrink-0 place-items-center">
        <svg
          viewBox="0 0 40 40"
          className="spin-slow absolute inset-0 h-full w-full text-brand-accent"
          fill="none"
          stroke="currentColor"
        >
          <circle cx="20" cy="20" r="17" strokeWidth="1" strokeDasharray="3 5" opacity="0.8" />
        </svg>
        <svg
          viewBox="0 0 40 40"
          className="spin-rev absolute inset-0 h-full w-full text-brand"
          fill="none"
          stroke="currentColor"
        >
          <circle cx="20" cy="20" r="12" strokeWidth="1" strokeDasharray="2 6" opacity="0.7" />
        </svg>
        <svg viewBox="0 0 24 24" className="relative h-3.5 w-3.5 text-brand-dark" fill="currentColor">
          <path d="M12 0c.6 6.6 4.8 10.8 12 12-7.2 1.2-11.4 5.4-12 12-.6-6.6-4.8-10.8-12-12C7.2 10.8 11.4 6.6 12 0Z" />
        </svg>
      </span>

      <svg viewBox="0 0 300 8" className="h-2 max-w-[38%] flex-1 text-brand/50" fill="none">
        <path
          d="M0 4h300"
          stroke="url(#gd-b)"
          strokeWidth="1.5"
          strokeLinecap="round"
          style={line}
        />
        <defs>
          <linearGradient id="gd-b" x1="0" y1="0" x2="300" y2="0">
            <stop stopColor="#8B5A3C" />
            <stop offset="1" stopColor="#D4A373" stopOpacity="0" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}

/**
 * A string of hanging lights across the top of a section.
 *
 * The wire is a single quadratic curve that sags the way a real one does; the
 * bulbs sit on it at the right heights and are each given their own twinkle
 * delay. Hung from the top edge, swinging very slightly, because a string of
 * lights that is perfectly still is a picture of a string of lights.
 */
export function Garland({ bulbs = 11 }: { bulbs?: number }) {
  // y of the sag at x, for a quadratic from (0,6) through (600,46) to (1200,6).
  const sag = (t: number) => 6 + 4 * 40 * t * (1 - t);

  return (
    <div
      className="pointer-events-none absolute inset-x-0 top-0 h-16 overflow-hidden"
      aria-hidden
    >
      <div className="swing origin-top">
        <svg viewBox="0 0 1200 64" preserveAspectRatio="none" className="h-16 w-full">
          <path
            d="M0 6Q600 86 1200 6"
            stroke="#B8835A"
            strokeOpacity="0.45"
            strokeWidth="1.6"
            fill="none"
          />
        </svg>

        {/* The bulbs are positioned in percentages over the same curve, so they
            follow the wire at any width without a second viewBox. */}
        {Array.from({ length: bulbs }, (_, i) => {
          const t = (i + 0.5) / bulbs;
          const y = sag(t);
          const warm = i % 2 === 0;
          return (
            <span
              key={i}
              className="absolute"
              style={{ left: `${t * 100}%`, top: y, transform: 'translateX(-50%)' }}
            >
              <span
                className="block h-2.5 w-2.5 rounded-full"
                style={{
                  background: warm
                    ? 'radial-gradient(circle at 35% 30%, #FFF6E2, #E8C9A0)'
                    : 'radial-gradient(circle at 35% 30%, #FFFFFF, #EBBDB4)',
                  boxShadow: warm
                    ? '0 0 10px 3px rgba(232,201,160,0.75)'
                    : '0 0 10px 3px rgba(235,189,180,0.7)',
                  animation: `twinkle ${2.2 + ((i * 7) % 18) / 10}s ease-in-out ${
                    ((i * 13) % 30) / 10
                  }s infinite`,
                }}
              />
            </span>
          );
        })}
      </div>
    </div>
  );
}

/** Two interlocking rings — the mark that says "this is a wedding site". */
export function Rings({ className = '' }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 64 44"
      className={`text-brand ${className}`}
      fill="none"
      stroke="currentColor"
      strokeWidth="2.4"
      aria-hidden
    >
      <circle cx="24" cy="24" r="15" opacity="0.85" />
      <circle cx="42" cy="24" r="15" opacity="0.6" />
      {/* The stone, catching the light on its own rhythm. */}
      <path
        d="M24 9l4 5-4 5-4-5 4-5Z"
        fill="currentColor"
        stroke="none"
        className="twinkle"
      />
    </svg>
  );
}

/** The wave that separates a coloured band from the page beneath it. */
export function WaveDivider({ flip = false }: { flip?: boolean }) {
  return (
    <div
      className={`pointer-events-none -mb-px w-full leading-[0] ${flip ? 'rotate-180' : ''}`}
      aria-hidden
    >
      <svg viewBox="0 0 1440 60" preserveAspectRatio="none" className="h-10 w-full">
        <path
          d="M0 30c180 30 360 30 540 10S900-5 1080 5s270 25 360 30v25H0Z"
          fill="currentColor"
        />
      </svg>
    </div>
  );
}
