'use client';

/**
 * Wraps every page, and is re-created on each navigation — which is exactly
 * what makes it the right place for a page transition: the CSS animation runs
 * again on mount, so moving between routes eases in instead of snapping.
 *
 * A `layout.tsx` would not do this: layouts persist across navigations, so the
 * animation would play once and never again.
 */
export default function Template({ children }: { children: React.ReactNode }) {
  return <div className="page-enter">{children}</div>;
}
