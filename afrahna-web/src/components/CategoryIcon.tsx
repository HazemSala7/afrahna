/**
 * A line icon per top-level category.
 *
 * The API stores two things here and neither works in a 32-pixel tile: `icon`
 * is a name the dashboard picked ("building", "dress") rather than a file, and
 * `image` is a full-bleed category photograph that turns into a dark smudge at
 * that size. Nine smudges in a row is what "unprofessional" looks like.
 *
 * So the rail draws its own icons — one weight, one colour, no requests, and
 * they stay sharp on any screen. Matching is on the dashboard's `icon` name
 * first and the Arabic title second, so renaming a category in Arabic does not
 * silently drop its icon.
 */
const PATHS: Record<string, React.ReactNode> = {
  beauty: (
    <>
      <path d="M12 3c2.5 2.6 4 5 4 7a4 4 0 1 1-8 0c0-2 1.5-4.4 4-7Z" />
      <path d="M9 20h6" />
    </>
  ),
  venue: (
    <>
      <path d="M3 21h18M5 21V9l7-5 7 5v12" />
      <path d="M10 21v-5h4v5" />
    </>
  ),
  party: (
    <>
      <path d="M4 20l5.5-11L15 14.5 4 20Z" />
      <path d="M15 4v2M19 8h2M17.5 5.5l1.5-1.5" />
    </>
  ),
  dress: (
    <>
      <path d="M9 3l3 2 3-2 1 4-2 2 2 10H8l2-10-2-2 1-4Z" />
    </>
  ),
  food: (
    <>
      <path d="M4 4v7a3 3 0 0 0 6 0V4M7 11v9" />
      <path d="M17 4c-1.5 2-2 4-2 6h4c0-2-.5-4-2-6ZM17 10v10" />
    </>
  ),
  gift: (
    <>
      <rect x="3" y="9" width="18" height="11" rx="2" />
      <path d="M3 13h18M12 9v11" />
      <path d="M12 9S9.5 4 7.5 5.5 9.5 9 12 9s4.5-5 4.5-3.5S12 9 12 9Z" />
    </>
  ),
  car: (
    <>
      <path d="M4 16v3M20 16v3" />
      <path d="M3 16v-3l2-5h14l2 5v3H3Z" />
      <circle cx="7.5" cy="16" r="1.6" />
      <circle cx="16.5" cy="16" r="1.6" />
    </>
  ),
  home: (
    <>
      <path d="M4 11l8-6 8 6v9H4v-9Z" />
      <path d="M9 20v-6h6v6" />
    </>
  ),
  more: (
    <>
      <circle cx="6" cy="12" r="1.6" />
      <circle cx="12" cy="12" r="1.6" />
      <circle cx="18" cy="12" r="1.6" />
    </>
  ),
  grid: (
    <>
      <rect x="3" y="3" width="7.5" height="7.5" rx="2" />
      <rect x="13.5" y="3" width="7.5" height="7.5" rx="2" />
      <rect x="3" y="13.5" width="7.5" height="7.5" rx="2" />
      <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2" />
    </>
  ),
};

/** Dashboard icon names, then Arabic titles, then the generic grid. */
function pick(icon?: string | null, title?: string): keyof typeof PATHS {
  const key = (icon ?? '').trim().toLowerCase();
  const byName: Record<string, keyof typeof PATHS> = {
    building: 'venue',
    dress: 'dress',
    gifts: 'gift',
    cars: 'car',
    'home & furniture': 'home',
    services: 'more',
  };
  if (byName[key]) return byName[key];

  const t = title ?? '';
  if (t.includes('تجميل')) return 'beauty';
  if (t.includes('حجوزات') || t.includes('قاعات')) return 'venue';
  if (t.includes('حفلات')) return 'party';
  if (t.includes('أزياء') || t.includes('موضة')) return 'dress';
  if (t.includes('طعام') || t.includes('ضياف')) return 'food';
  if (t.includes('هدايا')) return 'gift';
  if (t.includes('سيارات')) return 'car';
  if (t.includes('منزل') || t.includes('أثاث')) return 'home';
  if (t.includes('المزيد')) return 'more';
  return 'grid';
}

export default function CategoryIcon({
  icon,
  title,
  size = 26,
}: {
  icon?: string | null;
  title?: string;
  size?: number;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {PATHS[pick(icon, title)]}
    </svg>
  );
}
