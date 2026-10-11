'use client';

import { API_BASE } from '@/lib/api';
import { whatsappHref } from '@/lib/format';
import type { Vendor } from '@/lib/types';

/**
 * The row of ways to reach a shop.
 *
 * This is what the page exists for: someone found the photographer they want
 * and now needs to talk to them. WhatsApp comes first because that is how this
 * business is actually done here, and every link is a real `tel:` / `https:`
 * so it works from the browser with nothing installed.
 *
 * Each press is also counted, so the dashboard can show the advertiser how
 * often people reach for him. The count is sent with `sendBeacon` where the
 * browser has it — the page is usually navigating away a moment later, and a
 * normal fetch would be cancelled mid-flight.
 */

/** Channel names the API accepts; anything else is rejected there. */
type Channel =
  | 'phone'
  | 'whatsapp'
  | 'map'
  | 'website'
  | 'instagram'
  | 'facebook'
  | 'tiktok';

function countTap(vendorId: number, channel: Channel): void {
  if (!vendorId) return;
  const url = `${API_BASE}/vendors/${vendorId}/contact-click`;
  try {
    // A counter is never worth blocking the call the visitor just asked for,
    // so failures are swallowed on both paths.
    if (typeof navigator !== 'undefined' && navigator.sendBeacon) {
      // Form-encoded, not JSON: it is a CORS-safelisted content type, so the
      // beacon goes straight out with no preflight to lose the race against
      // the page navigating away. Laravel reads it the same either way.
      navigator.sendBeacon(
        url,
        new Blob([`channel=${encodeURIComponent(channel)}`], {
          type: 'application/x-www-form-urlencoded',
        }),
      );
      return;
    }
    void fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ channel }),
      keepalive: true,
    }).catch(() => undefined);
  } catch {
    /* ignore */
  }
}

export default function ContactBar({ vendor }: { vendor: Vendor }) {
  const wa = whatsappHref(vendor.whatsapp || vendor.phone);
  const map =
    vendor.latitude && vendor.longitude
      ? `https://maps.google.com/?q=${vendor.latitude},${vendor.longitude}`
      : null;

  const socials = [
    { href: vendor.instagram, label: 'إنستغرام', icon: 'instagram', channel: 'instagram' as Channel },
    { href: vendor.facebook, label: 'فيسبوك', icon: 'facebook', channel: 'facebook' as Channel },
    { href: vendor.tiktok, label: 'تيك توك', icon: 'tiktok', channel: 'tiktok' as Channel },
    { href: vendor.website, label: 'الموقع', icon: 'link', channel: 'website' as Channel },
  ].filter(
    (s): s is { href: string; label: string; icon: string; channel: Channel } =>
      Boolean(s.href),
  );

  const hasAnything = wa || vendor.phone || map || socials.length > 0;
  if (!hasAnything) return null;

  const count = (channel: Channel) => () => countTap(vendor.id, channel);

  return (
    <div className="card flex flex-wrap items-center gap-2 p-4">
      {wa && (
        <a
          href={wa}
          target="_blank"
          rel="noopener noreferrer"
          onClick={count('whatsapp')}
          className="btn bg-[#25D366] text-white hover:brightness-95"
        >
          واتساب
        </a>
      )}
      {vendor.phone && (
        <a href={`tel:${vendor.phone}`} onClick={count('phone')} className="btn-primary">
          اتصال
        </a>
      )}
      {map && (
        <a
          href={map}
          target="_blank"
          rel="noopener noreferrer"
          onClick={count('map')}
          className="btn-ghost"
        >
          الموقع على الخريطة
        </a>
      )}
      {socials.map((s) => (
        <a
          key={s.icon}
          href={normalise(s.href)}
          target="_blank"
          rel="noopener noreferrer"
          onClick={count(s.channel)}
          className="btn-ghost !px-4"
        >
          {s.label}
        </a>
      ))}
    </div>
  );
}

/** Shops type their handles inconsistently; a bare domain is still a link. */
function normalise(href: string): string {
  const t = href.trim();
  if (/^https?:\/\//i.test(t)) return t;
  if (t.startsWith('@')) return `https://instagram.com/${t.slice(1)}`;
  return `https://${t}`;
}
