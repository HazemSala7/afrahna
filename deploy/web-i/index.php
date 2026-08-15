<?php
// The wedding invitation, on the web:  https://afrahna.co/i/{CODE}
//
// This is the invitation itself, not a gateway to the app: a sealed envelope
// that opens, the couple's names over the cover artwork, countdown, venue,
// gallery, attendance reply and guestbook — the same experience the app gives,
// for guests who will never install anything.
//
// Art direction is "engraved stationery": ivory stock, hairline gold rules,
// a wax seal and a Ruqaa display face. Three rules keep it from looking like a
// web page wearing a wedding costume —
//   1. the invitation is always a PORTRAIT CARD. The cover art is shot for a
//      phone, so on a desktop the whole thing is centred in a 520px column
//      over a blurred field of its own artwork instead of being stretched
//      across 1600px of empty wall;
//   2. the cover art is never blacked out. It is vignetted in the theme's own
//      background colour so a pale floral photograph stays pale;
//   3. no letter-spacing on Arabic. Tracking is a Latin small-caps device; on
//      Arabic it prises connected letters apart. The eyebrows get their air
//      from word-spacing and flanking hairlines instead.
//
// Everything is inlined (no build step, no CDN) so the page is one request and
// works on any phone that can open a link.

$uri = $_SERVER['REQUEST_URI'] ?? '';
if (preg_match('#/i/([A-Za-z0-9]{4,24})#', $uri, $m)) {
    $code = $m[1];
} else {
    $code = preg_replace('/[^A-Za-z0-9]/', '', $_GET['code'] ?? '');
}

$api = 'https://afrahna.co/admin/api/v1';
$d   = null;
if ($code !== '') {
    $ctx  = stream_context_create(['http' => ['timeout' => 8]]);
    $json = @file_get_contents("$api/invitations/public/$code", false, $ctx);
    if ($json) {
        $tmp = json_decode($json, true);
        if (! empty($tmp['found'])) $d = $tmp;
    }
}

$e = fn ($s) => htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');

if (! $d) {
    http_response_code(404);
    echo '<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8">'
       . '<meta name="viewport" content="width=device-width,initial-scale=1">'
       . '<title>الدعوة غير متاحة</title>'
       . '<body style="background:#11131C;color:#F6EFE3;font-family:Tahoma,sans-serif;'
       . 'display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center">'
       . '<div><h1 style="font-weight:600">الدعوة غير متاحة</h1>'
       . '<p style="opacity:.7">تأكد من الرابط أو اطلب رابطًا جديدًا من صاحب الدعوة.</p></div>';
    exit;
}

$groom  = $d['groom_name'] ?? '';
$bride  = $d['bride_name'] ?? '';
$venue  = $d['venue'] ?? '';
$mapUrl = $d['map_url'] ?? '';
$msg    = $d['custom_message'] ?? '';
$gift   = $d['gift_note'] ?? '';
$accent = $d['accent_color'] ?: '#C9A24D';
// Absolute, because it is also the og:image every chat app will fetch.
$art    = $d['background_image'] ?: 'https://afrahna.co/i/cover.jpg';
$font   = trim((string) ($d['font_family'] ?? ''));
$bg     = $d['bg_color'] ?: '#3A3F44';
$anim   = $d['animation'] ?? 'bokeh';
$open   = ! empty($d['rsvp_open']);
$conf   = (int) ($d['confirmed_count'] ?? 0);
$wishes = $d['wishes'] ?? [];
$gallery = $d['gallery'] ?? [];

$months = [1=>'يناير','فبراير','مارس','أبريل','مايو','يونيو',
           'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
$days   = [1=>'الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];

$ts    = ! empty($d['event_date']) ? strtotime($d['event_date']) : null;
$dayNm = $ts ? $days[(int) date('N', $ts)] : '';
$dayNo = $ts ? date('j', $ts) : '';
$monNm = $ts ? $months[(int) date('n', $ts)] : '';
$year  = $ts ? date('Y', $ts) : '';
$when  = $ts ? "$dayNo $monNm $year" : '';
$clock = $ts ? date('H:i', $ts) : '';
$iso   = $ts ? date('c', $ts) : '';

// "Add to calendar" — a link, not a download, so it works inside the in-app
// browsers most guests will open this from.
$gcal = '';
if ($ts) {
    $gcal = 'https://calendar.google.com/calendar/render?' . http_build_query([
        'action'   => 'TEMPLATE',
        'text'     => "زفاف $groom و $bride",
        'dates'    => gmdate('Ymd\THis\Z', $ts) . '/' . gmdate('Ymd\THis\Z', $ts + 5 * 3600),
        'location' => $venue,
        'details'  => 'دعوة أفراحنا',
    ]);
}

// Every tint of the theme's two colours is mixed here rather than with CSS
// color-mix(), which older phone browsers do not understand — and when they
// drop it the whole gold palette computes to black. sRGB mixing is a plain
// linear blend, so the result is identical where color-mix is supported.
$rgb = function (string $hex): array {
    $hex = ltrim(trim($hex), '#');
    if (strlen($hex) === 3) $hex = $hex[0].$hex[0].$hex[1].$hex[1].$hex[2].$hex[2];
    if (strlen($hex) !== 6 || ! ctype_xdigit($hex)) return [0, 0, 0];
    return [hexdec(substr($hex, 0, 2)), hexdec(substr($hex, 2, 2)), hexdec(substr($hex, 4, 2))];
};
/** $pct of $a over $b, as #rrggbb. */
$mix = function (string $a, float $pct, string $b) use ($rgb): string {
    [$ar, $ag, $ab] = $rgb($a); [$br, $bg2, $bb] = $rgb($b); $p = $pct / 100;
    return sprintf('#%02X%02X%02X',
        (int) round($ar * $p + $br * (1 - $p)),
        (int) round($ag * $p + $bg2 * (1 - $p)),
        (int) round($ab * $p + $bb * (1 - $p)));
};
/** The colour at $pct opacity — what mixing with `transparent` means. */
$fade = function (string $c, float $pct) use ($rgb): string {
    [$r, $g, $b] = $rgb($c);
    return sprintf('rgba(%d,%d,%d,%.2f)', $r, $g, $b, $pct / 100);
};

$lum = function (string $hex) use ($rgb): float {
    $c = array_map(function ($v) {
        $v /= 255;
        return $v <= 0.03928 ? $v / 12.92 : pow(($v + 0.055) / 1.055, 2.4);
    }, $rgb($hex));
    return 0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2];
};
$ratio = function (string $a, string $b) use ($lum): float {
    $la = $lum($a); $lb = $lum($b);
    return (max($la, $lb) + 0.05) / (min($la, $lb) + 0.05);
};

// Label ink. A champagne or blush accent printed straight onto ivory sits at
// about 3.5:1, so the accent is walked towards its dark base until it clears
// 4.5:1 — the same rule then holds for whatever colour a theme is given.
$paper   = '#F6F2EA';
$inkGold = $mix($accent, 58, '#46320C');
for ($p = 58; $p > 6 && $ratio($inkGold, $paper) < 4.5; $p -= 4) {
    $inkGold = $mix($accent, $p, '#46320C');
}
$hair     = $mix($accent, 42, '#C9BCA0');   // rules, not text: these stay light
$hairSoft = $mix($accent, 22, '#E3D9C6');

// Initials for the wax seal and the crest: first letter of each name.
$initial = fn ($s) => mb_substr(trim((string) $s), 0, 1, 'UTF-8');
$mono    = trim($initial($groom) . '·' . $initial($bride), '·');

// A sprig of two curved stems, the one ornament reused everywhere: crest,
// section rules, footer. Drawn once, coloured by currentColor.
$sprig = '<svg class="sprig" viewBox="0 0 80 26" aria-hidden="true">'
       . '<g fill="none" stroke="currentColor" stroke-width=".9" stroke-linecap="round">'
       . '<path d="M40 20C31 20 19 17 9 9"/><path d="M40 20c9 0 21-3 31-11"/></g>'
       . '<g fill="currentColor" opacity=".92">'
       . '<ellipse rx="4.1" ry="1.75" transform="translate(32 17.2) rotate(-20)"/>'
       . '<ellipse rx="3.8" ry="1.65" transform="translate(25 15.2) rotate(-27)"/>'
       . '<ellipse rx="3.3" ry="1.5"  transform="translate(18 12.2) rotate(-34)"/>'
       . '<ellipse rx="4.1" ry="1.75" transform="translate(48 17.2) rotate(20)"/>'
       . '<ellipse rx="3.8" ry="1.65" transform="translate(55 15.2) rotate(27)"/>'
       . '<ellipse rx="3.3" ry="1.5"  transform="translate(62 12.2) rotate(34)"/>'
       . '</g><path d="M40 16.6l2.5 2.7-2.5 2.7-2.5-2.7z" fill="currentColor"/></svg>';

$title = "دعوة زفاف $groom و $bride";
$desc  = $when ? "يسعدنا حضوركم — $when" . ($clock ? " — $clock" : '') : 'يسعدنا حضوركم';
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title><?= $e($title) ?></title>
<meta property="og:title" content="<?= $e($title) ?>">
<meta property="og:description" content="<?= $e($desc) ?>">
<meta property="og:type" content="website">
<meta property="og:image" content="<?= $e($art) ?>">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="<?= $e($bg) ?>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Amiri:ital,wght@0,400;0,700;1,400&family=Aref+Ruqaa:wght@400;700&family=Cormorant+Garamond:ital,wght@0,300;0,400;0,500;1,300;1,400<?php
  if ($font && ! in_array($font, ['Amiri','Aref Ruqaa','Cormorant Garamond'], true)) {
      echo '&family=' . rawurlencode(str_replace(' ', '+', $font)) . ':wght@400;700';
  } ?>&display=swap" rel="stylesheet">
<style>
:root{
  --accent:<?= $e($accent) ?>;
  --bg:<?= $e($bg) ?>;
  --paper:#F6F2EA;
  --card:#FFFDF8;
  --heading:#2B2620;
  --body:#6E655A;
  /* A pale champagne accent is invisible as text on ivory, so everything
     printed on paper uses the same hue driven down into readable gold. */
  --ink-gold:<?= $inkGold ?>;
  --hair:<?= $hair ?>;
  --hair-soft:<?= $hairSoft ?>;
  --sheet:520px;
}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
[hidden]{display:none!important}
html,body{margin:0;padding:0}
html{scroll-behavior:smooth}
body{background:var(--paper);font-family:'Amiri',Tahoma,serif;color:var(--body);
     overflow-x:hidden;-webkit-font-smoothing:antialiased}
.display{font-family:<?= $font ? "'".$e($font)."'," : '' ?>'Aref Ruqaa',serif}
.latin{font-family:'Cormorant Garamond',serif;font-variant-numeric:oldstyle-nums}
/* Arabic small label. The airiness comes from word-spacing and size, never
   from letter-spacing, which would break the joins between letters. */
.lbl{font-family:'Amiri',serif;word-spacing:.16em;letter-spacing:0;font-weight:400}
.sprig{width:70px;height:23px;display:block}
img{max-width:100%}

/* ---------- the card: a portrait invitation, never a stretched web page ---- */
#shell{position:relative;z-index:2;max-width:var(--sheet);margin:0 auto;
       background:var(--paper);min-height:100vh}
#field{position:fixed;inset:0;z-index:0;background:#14161A}
#field b{position:absolute;inset:-8%;display:block;
  background:url('<?= $e($art) ?>') center/cover no-repeat;
  filter:blur(58px) saturate(.85) brightness(.62)}
/* A pool of light behind the card and darkness at the corners, so the
   invitation reads as an object lying on a table rather than a page. */
#field i{position:absolute;inset:0;display:block;background:
  radial-gradient(ellipse 74% 86% at 50% 44%,rgba(0,0,0,.02),rgba(0,0,0,.34) 52%,rgba(0,0,0,.74) 100%)}
@media (min-width:860px){
  #shell{box-shadow:0 44px 120px rgba(0,0,0,.62),0 8px 26px rgba(0,0,0,.4),
         0 0 0 1px rgba(255,255,255,.07)}
}
/* Film grain over everything, the thing that makes flat colour look printed. */
#grain{position:fixed;inset:0;z-index:45;pointer-events:none;opacity:.30;
  mix-blend-mode:multiply;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.86' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='saturate' values='0'/%3E%3C/filter%3E%3Crect width='140' height='140' filter='url(%23n)' opacity='.42'/%3E%3C/svg%3E");
  background-size:140px 140px}

/* ---------- envelope ---------- */
/* A real object lying in a dark room, not two triangles filling the screen:
   a portrait envelope seen from the back, its flap hinged at the top edge and
   a wax seal pressed over the point where the flap closes. */
#env{position:fixed;inset:0;z-index:80;display:flex;flex-direction:column;
  align-items:center;justify-content:center;gap:34px;cursor:pointer;overflow:hidden;
  background:radial-gradient(ellipse 70% 55% at 50% 44%,
             <?= $mix($bg, 82, '#FFFFFF') ?>,
             <?= $mix($bg, 34, '#0A0B0D') ?> 100%)}
#env.gone{opacity:0;pointer-events:none;transition:opacity .9s ease}
.envelope{position:relative;width:min(74%,306px);aspect-ratio:.76;perspective:1000px;
  filter:drop-shadow(0 30px 44px rgba(0,0,0,.5))}
.paper{position:absolute;background:linear-gradient(152deg,#FBF5EA,#EFE3CE 58%,#DDCDAF)}
/* Blind-embossed florals: white motifs with a soft drop-shadow read as
   pressed into the stock. Two tiles at different scales and rotations so the
   relief never resolves into an obvious repeating grid. */
.paper:before,.paper:after{content:'';position:absolute;inset:-10%;pointer-events:none}
.paper:before{opacity:.5;transform:rotate(-4deg);
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='300' height='300' viewBox='0 0 300 300'%3E%3Cg fill='none' stroke='%23ffffff' stroke-width='1.6' stroke-linecap='round' opacity='.9'%3E%3Cpath d='M52 236 C58 198 56 156 52 118'/%3E%3Cpath d='M52 216 l13 -10 M52 216 l-13 -10 M52 196 l12 -9 M52 196 l-12 -9 M52 176 l11 -8 M52 176 l-11 -8 M52 156 l10 -7 M52 156 l-10 -7 M52 138 l8 -6 M52 138 l-8 -6'/%3E%3Cpath d='M238 268 C244 232 242 192 238 156'/%3E%3Cpath d='M238 248 l12 -9 M238 248 l-12 -9 M238 228 l11 -8 M238 228 l-11 -8 M238 208 l10 -7 M238 208 l-10 -7 M238 190 l9 -7 M238 190 l-9 -7'/%3E%3C/g%3E%3Cg fill='%23ffffff' opacity='.95'%3E%3Cg transform='translate(158,72)'%3E%3Cellipse rx='13' ry='6.5'/%3E%3Cellipse rx='13' ry='6.5' transform='rotate(36)'/%3E%3Cellipse rx='13' ry='6.5' transform='rotate(72)'/%3E%3Cellipse rx='13' ry='6.5' transform='rotate(108)'/%3E%3Cellipse rx='13' ry='6.5' transform='rotate(144)'/%3E%3Ccircle r='4.4' fill='%23f3ead9'/%3E%3C/g%3E%3Cg transform='translate(110,188)'%3E%3Cellipse rx='10' ry='5'/%3E%3Cellipse rx='10' ry='5' transform='rotate(36)'/%3E%3Cellipse rx='10' ry='5' transform='rotate(72)'/%3E%3Cellipse rx='10' ry='5' transform='rotate(108)'/%3E%3Cellipse rx='10' ry='5' transform='rotate(144)'/%3E%3Ccircle r='3.4' fill='%23f3ead9'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
  background-size:190px 190px;
  filter:drop-shadow(.8px 1.1px .4px rgba(107,88,54,.20))}
.paper:after{opacity:.3;transform:rotate(7deg) scale(.72);
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='300' height='300' viewBox='0 0 300 300'%3E%3Cg fill='%23ffffff'%3E%3Cg transform='translate(70,120)'%3E%3Cellipse rx='9' ry='4.6'/%3E%3Cellipse rx='9' ry='4.6' transform='rotate(45)'/%3E%3Cellipse rx='9' ry='4.6' transform='rotate(90)'/%3E%3Cellipse rx='9' ry='4.6' transform='rotate(135)'/%3E%3Ccircle r='3' fill='%23f3ead9'/%3E%3C/g%3E%3Cg transform='translate(222,44)'%3E%3Cellipse rx='7' ry='3.6'/%3E%3Cellipse rx='7' ry='3.6' transform='rotate(45)'/%3E%3Cellipse rx='7' ry='3.6' transform='rotate(90)'/%3E%3Cellipse rx='7' ry='3.6' transform='rotate(135)'/%3E%3Ccircle r='2.4' fill='%23f3ead9'/%3E%3C/g%3E%3Cpath d='M186 250 q6 -12 0 -24 q-6 12 0 24' /%3E%3Cpath d='M40 268 q5 -10 0 -20 q-5 10 0 20' /%3E%3C/g%3E%3C/svg%3E");
  background-size:190px 190px;
  filter:drop-shadow(.7px 1px .3px rgba(107,88,54,.16))}
.ebody{inset:0;overflow:hidden}
/* The three back flaps, each a shade darker where paper lies over paper. */
.fold{position:absolute;display:block;z-index:2}
.fold.l{left:0;top:0;width:50.4%;height:100%;background:rgba(150,124,80,.09);
  clip-path:polygon(0 0,100% 50%,0 100%)}
.fold.r{right:0;top:0;width:50.4%;height:100%;background:rgba(150,124,80,.06);
  clip-path:polygon(100% 0,0 50%,100% 100%)}
.fold.b{left:0;bottom:0;width:100%;height:54%;background:rgba(150,124,80,.13);
  clip-path:polygon(0 100%,50% 0,100% 100%)}
.flap{left:0;top:0;width:100%;height:54%;z-index:4;transform-origin:top center;
  clip-path:polygon(0 0,100% 0,50% 100%);
  background:linear-gradient(180deg,#FDF8F0,#E8DBC3);
  transition:transform 1.05s cubic-bezier(.72,.02,.28,1)}
#env.open .flap{transform:rotateX(-172deg);
  background:linear-gradient(0deg,#F6EDDC,#E0D0B0)}
/* Wax: an organic blob rather than a circle, pressed at the flap's point. */
.seal{position:absolute;left:50%;top:54%;width:80px;height:80px;z-index:5;
  transform:translate(-50%,-50%);
  border-radius:52% 48% 55% 45%/47% 56% 44% 53%;
  display:flex;align-items:center;justify-content:center;overflow:hidden;
  /* Wax is matte: a broad soft light, no specular hotspot, and the edge
     darker than the middle because the pour is thicker there. */
  background:radial-gradient(circle at 40% 34%,
             <?= $mix($accent, 74, '#FFFFFF') ?> 0%,var(--accent) 46%,
             <?= $mix($accent, 56, '#3B2807') ?> 100%);
  box-shadow:0 9px 17px rgba(0,0,0,.42),inset 0 -5px 11px rgba(64,44,9,.30),
             inset 0 2px 5px rgba(255,255,255,.18);
  transition:transform .7s cubic-bezier(.5,0,.2,1),opacity .55s ease}
.seal:before{content:'';position:absolute;inset:9px;border-radius:inherit;
  border:1px solid rgba(60,42,10,.20);box-shadow:0 1px 0 rgba(255,255,255,.16)}
.seal:after{content:'';position:absolute;inset:-40%;
  background:linear-gradient(72deg,transparent 43%,rgba(255,255,255,.17) 50%,transparent 57%);
  animation:sheen 4.2s ease-in-out infinite}
@keyframes sheen{0%,70%{transform:translateX(-115%)}100%{transform:translateX(115%)}}
#env.open .seal{transform:translate(-50%,-50%) scale(1.6) rotate(11deg);opacity:0}
/* The monogram is struck into the wax, so it is darker than the seal with a
   thin lit edge underneath rather than a drop shadow over it. */
.seal span{position:relative;z-index:2;font-family:'Cormorant Garamond',serif;
  font-size:22px;color:<?= $mix($accent, 26, '#241903') ?>;
  text-shadow:0 1px 0 rgba(255,255,255,.26),0 -1px 1px rgba(40,28,4,.35)}
.tap{text-align:center;color:var(--accent);z-index:6;opacity:.92}
.tap .lbl{font-size:12.5px}
.tap em{display:block;width:1px;height:26px;margin:0 auto 12px;
  background:linear-gradient(180deg,transparent,var(--accent));animation:pulse 2.6s ease-in-out infinite}
@keyframes pulse{0%,100%{opacity:.25;transform:scaleY(.6)}50%{opacity:1;transform:scaleY(1)}}

/* ---------- hero ---------- */
/* The couple's names are printed on a vellum plate laid over the artwork,
   the way a real card sits on the flowers it was photographed with. It is the
   one composition that survives every theme: white type on the pale mist
   photograph would vanish, dark type on the emerald one would too, but ink on
   ivory reads on both — and it ties the cover to the paper below it. */
.hero{position:relative;min-height:100vh;min-height:100svh;display:flex;flex-direction:column;
  align-items:center;justify-content:center;text-align:center;padding:56px 26px 104px;
  overflow:hidden}
.hero .art{position:absolute;inset:-3%;
  background:url('<?= $e($art) ?>') center/cover no-repeat;
  animation:drift 30s ease-in-out infinite alternate}
@keyframes drift{from{transform:scale(1.03)}to{transform:scale(1.11) translate(-1.2%,1%)}}
/* A vignette in the theme's own colour, never black, so a pale photograph
   stays pale and a dark one stays dark — it only sinks the edges. */
.hero .tint{position:absolute;inset:0;background:
  radial-gradient(ellipse 78% 56% at 50% 46%,transparent 26%,
                  <?= $fade($bg, 34) ?> 62%,
                  <?= $fade($bg, 78) ?> 100%),
  linear-gradient(180deg,<?= $fade($bg, 46) ?>,transparent 24%,
                  transparent 62%,<?= $fade($bg, 66) ?>)}

.plate{position:relative;z-index:3;width:min(89%,394px);padding:8px;
  opacity:0;transform:scale(.965) translateY(10px);
  transition:opacity 1.1s ease,transform 1.4s cubic-bezier(.16,.8,.3,1);
  background:linear-gradient(165deg,rgba(255,253,248,.90),rgba(243,238,228,.84));
  -webkit-backdrop-filter:blur(8px) saturate(1.15);backdrop-filter:blur(8px) saturate(1.15);
  border:1px solid rgba(255,255,255,.72);
  box-shadow:0 30px 70px rgba(38,30,16,.34),0 3px 12px rgba(38,30,16,.16),
             inset 0 1px 0 rgba(255,255,255,.85)}
body.revealed .plate{opacity:1;transform:none}
.plate-in{border:1px solid var(--hair);padding:36px 24px 32px;
  display:flex;flex-direction:column;align-items:center}

.crest{display:flex;flex-direction:column;align-items:center;gap:11px;color:var(--ink-gold)}
.crest .ring{width:60px;height:60px;border-radius:50%;border:1px solid var(--hair);
  display:flex;align-items:center;justify-content:center;position:relative}
.crest .ring:before,.crest .ring:after{content:'';position:absolute;width:5px;height:5px;
  transform:rotate(45deg);background:var(--ink-gold);left:50%;margin-left:-2.5px;opacity:.75}
.crest .ring:before{top:-3px}.crest .ring:after{bottom:-3px}
.crest .ring span{font-family:'Cormorant Garamond',serif;font-size:19px;letter-spacing:.05em;
  color:var(--ink-gold)}
.hero .kicker{display:flex;align-items:center;gap:11px;margin:20px 0 0;font-size:11.5px;
  color:var(--ink-gold)}
.hero .kicker:before,.hero .kicker:after{content:'';width:22px;height:1px;background:var(--hair)}
.hero .names{display:flex;flex-direction:column;align-items:center;padding:26px 0 24px;width:100%}
.hero .nm{margin:0;font-size:clamp(31px,8.6vw,44px);line-height:1.34;font-weight:400;
  color:var(--heading)}
.hero .amp{display:flex;align-items:center;gap:18px;width:74%;margin:7px 0 5px}
.hero .amp:before,.hero .amp:after{content:'';flex:1;height:1px;
  background:linear-gradient(90deg,transparent,var(--hair))}
.hero .amp:after{background:linear-gradient(270deg,transparent,var(--hair))}
.hero .amp b{font-family:'Cormorant Garamond',serif;font-style:italic;font-weight:400;
  font-size:33px;color:var(--ink-gold);line-height:1}
.dateline{display:flex;align-items:center;justify-content:center;flex-wrap:wrap;
  gap:7px 11px;margin:0;padding-top:22px;border-top:1px solid var(--hair-soft);
  width:90%;color:var(--body)}
/* Each part stays whole: on a 360px phone the date must move to its own line
   rather than break between the month and the year. */
.dateline span{font-size:11.5px;word-spacing:.1em;white-space:nowrap}
.dateline .big{font-size:14.5px;color:var(--heading)}
.dateline i{width:1px;height:13px;background:var(--hair)}
.cue{position:absolute;bottom:98px;left:0;right:0;z-index:3;display:flex;flex-direction:column;
  align-items:center;gap:8px;color:#fff;text-decoration:none;font-size:11px;
  text-shadow:0 1px 8px rgba(0,0,0,.5)}
.cue em{width:1px;height:28px;background:rgba(255,255,255,.45);position:relative;overflow:hidden}
.cue em:after{content:'';position:absolute;inset:0;background:#fff;animation:trail 2.4s ease-in-out infinite}
@keyframes trail{0%{transform:translateY(-100%)}60%,100%{transform:translateY(100%)}}

/* Theme particles — bokeh drifting up, petals falling, arabesque shimmering. */
.fx{position:absolute;inset:0;z-index:2;pointer-events:none;overflow:hidden}
.fx b{position:absolute;display:block;bottom:-14%;border-radius:50%;filter:blur(1.5px);
  background:radial-gradient(circle,rgba(255,255,255,.5),rgba(255,255,255,.14) 45%,rgba(255,255,255,0) 72%);
  animation:rise linear infinite}
@keyframes rise{0%{transform:translateY(0) translateX(0);opacity:0}
  14%{opacity:.6}86%{opacity:.35}100%{transform:translateY(-118vh) translateX(22px);opacity:0}}
.fx.petals b{border-radius:56% 44% 50% 50%/72% 68% 32% 28%;bottom:auto;top:-10%;
  filter:none;transform-origin:50% 30%;
  background:linear-gradient(140deg,rgba(255,255,255,.88),<?= $mix($accent, 82, '#FFFFFF') ?>);
  box-shadow:0 1px 2px rgba(90,60,60,.10);animation-name:fall}
@keyframes fall{0%{transform:translateY(-10%) rotate(0);opacity:0}
  10%{opacity:.9}100%{transform:translateY(116vh) translateX(-40px) rotate(420deg);opacity:0}}
/* Arabesque is a pattern, not particles: an eight-point star lattice panning
   slowly behind the plate. */
.fx.arabesque b{display:none}
.fx.arabesque{opacity:.07;animation:pan 110s linear infinite;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cg fill='none' stroke='%23ffffff' stroke-width='1'%3E%3Crect x='27' y='27' width='66' height='66'/%3E%3Crect x='27' y='27' width='66' height='66' transform='rotate(45 60 60)'/%3E%3Ccircle cx='60' cy='60' r='9'/%3E%3Cpath d='M60 0v14M60 106v14M0 60h14M106 60h14'/%3E%3C/g%3E%3C/svg%3E");
  background-size:168px 168px}
@keyframes pan{to{background-position:168px 168px}}

/* ---------- paper ---------- */
.fade{height:96px;margin-top:-96px;position:relative;z-index:4;
  background:linear-gradient(180deg,transparent,var(--paper) 88%)}
main{padding:0 26px 130px;position:relative;z-index:4}
.sec{margin:60px 0;text-align:center}
.eyebrow{display:flex;align-items:center;justify-content:center;gap:11px;
  font-size:11.5px;color:var(--ink-gold);margin:0 0 13px}
.eyebrow:before,.eyebrow:after{content:'';width:20px;height:1px;background:var(--hair)}
.sec h2{font-size:26px;color:var(--heading);margin:0;font-weight:400;line-height:1.5}
.card{background:var(--card);border:1px solid var(--hair-soft);padding:26px 22px;
  box-shadow:0 1px 0 rgba(255,255,255,.9) inset,0 14px 34px rgba(78,64,40,.07)}
.card.ruled{position:relative}
.card.ruled:before{content:'';position:absolute;inset:6px;border:1px solid var(--hair-soft);
  pointer-events:none}
.orn{display:flex;align-items:center;justify-content:center;gap:14px;margin:52px 0;
  color:var(--ink-gold);opacity:.72}
.orn:before,.orn:after{content:'';flex:1;max-width:120px;height:1px;
  background:linear-gradient(90deg,transparent,var(--hair))}
.orn:after{background:linear-gradient(270deg,transparent,var(--hair))}

/* reveal on scroll */
.up{opacity:0;transform:translateY(18px);transition:opacity .9s ease,transform .9s cubic-bezier(.2,.7,.3,1)}
.up.in{opacity:1;transform:none}

/* countdown */
.count{display:flex;justify-content:center;align-items:flex-start}
.count div{flex:1;position:relative;padding:2px 4px}
.count div+div:before{content:'';position:absolute;right:0;top:6px;bottom:16px;width:1px;
  background:var(--hair-soft)}
.count b{display:block;font-family:'Cormorant Garamond',serif;font-weight:400;
  font-size:34px;line-height:1.1;color:var(--heading);font-variant-numeric:lining-nums}
.count span{font-size:12px;color:var(--ink-gold);display:block;margin-top:6px;opacity:.9}
.cal{display:inline-flex;align-items:center;gap:8px;margin-top:20px;font-size:12px;
  color:var(--ink-gold);text-decoration:none;border-bottom:1px solid var(--hair-soft);
  padding-bottom:4px}
.cal svg{width:13px;height:13px;fill:none;stroke:currentColor;stroke-width:1.3}

/* message */
.quote{font-size:17.5px;line-height:2.3;color:var(--heading);margin:0;position:relative}
.quote:before{content:'”';display:block;font-family:'Cormorant Garamond',serif;font-size:56px;
  line-height:.4;color:var(--ink-gold);opacity:.4;margin-bottom:20px}

/* venue */
.pinwrap{width:52px;height:52px;border-radius:50%;border:1px solid var(--hair);
  display:flex;align-items:center;justify-content:center;margin:0 auto 16px;color:var(--ink-gold)}
.pinwrap svg{width:21px;height:21px;fill:none;stroke:currentColor;stroke-width:1.2}
.venue-name{font-size:21px;color:var(--heading);margin:0;line-height:1.7}
.btn{display:inline-flex;align-items:center;gap:9px;justify-content:center;
  padding:13px 28px;text-decoration:none;font-size:14px;cursor:pointer;
  font-family:'Amiri',serif;word-spacing:.14em;
  border:1px solid var(--hair);color:var(--ink-gold);background:transparent;
  transition:background .3s ease,color .3s ease}
.btn:hover{background:<?= $fade($accent, 14) ?>}
.btn svg{width:14px;height:14px;fill:none;stroke:currentColor;stroke-width:1.3}
.btn.solid{width:100%;padding:16px;font-size:15px;color:#FFFBF2;border:0;
  position:relative;overflow:hidden;
  /* Foil-stamped: a light across the top, the ink deeper at both ends. */
  background:linear-gradient(180deg,rgba(255,255,255,.17),rgba(0,0,0,.09)),
             linear-gradient(100deg,<?= $mix($accent, 50, '#332306') ?>,
             var(--ink-gold) 44%,<?= $mix($accent, 50, '#332306') ?>);
  box-shadow:inset 0 1px 0 rgba(255,255,255,.26),0 9px 20px rgba(70,50,12,.20)}
.btn.solid:after{content:'';position:absolute;inset:0;
  background:linear-gradient(100deg,transparent 40%,rgba(255,255,255,.35) 50%,transparent 60%);
  transform:translateX(-100%);transition:transform .8s ease}
.btn.solid:hover:after{transform:translateX(100%)}

/* gallery */
.gal{display:flex;gap:14px;overflow-x:auto;padding:6px 0 14px;scroll-snap-type:x mandatory;
  scrollbar-width:none}
.gal::-webkit-scrollbar{display:none}
.gal figure{margin:0;flex:0 0 auto;scroll-snap-align:center;background:#fff;padding:9px;
  box-shadow:0 12px 26px rgba(78,64,40,.16);cursor:zoom-in}
.gal img{height:230px;width:auto;display:block;object-fit:cover}
#lb{position:fixed;inset:0;z-index:90;background:rgba(12,12,14,.94);display:none;
  align-items:center;justify-content:center;padding:20px;cursor:zoom-out}
#lb.on{display:flex}
#lb img{max-width:100%;max-height:90vh;box-shadow:0 30px 80px rgba(0,0,0,.6)}

/* forms */
.field{text-align:right;margin:24px 0}
.field label{display:block;font-size:11.5px;color:var(--ink-gold);margin-bottom:7px}
.field input,.field textarea{width:100%;border:0;border-bottom:1px solid var(--hair);
  background:transparent;padding:8px 2px;font-family:'Amiri',serif;font-size:15.5px;
  color:var(--heading);resize:none;transition:border-color .3s ease}
.field input:focus,.field textarea:focus{outline:0;border-bottom-color:var(--ink-gold)}
.field input::placeholder,.field textarea::placeholder{color:#B9AF9E}
.choices{display:flex;border:1px solid var(--hair);margin:22px 0 0}
.choices button{flex:1;padding:14px 6px;cursor:pointer;background:transparent;border:0;
  font-family:'Amiri',serif;font-size:14px;color:var(--body);
  transition:background .3s ease,color .3s ease}
.choices button+button{border-right:1px solid var(--hair)}
.choices button[aria-pressed="true"]{background:var(--ink-gold);color:#FFFBF2}
.stepper{display:flex;align-items:center;justify-content:space-between;margin:22px 0 4px;
  font-size:13px;color:var(--body)}
.stepper .ctl{display:flex;align-items:center;gap:18px;border:1px solid var(--hair);padding:7px 14px}
.stepper button{border:0;background:none;font-size:17px;color:var(--ink-gold);cursor:pointer;
  line-height:1;font-family:'Cormorant Garamond',serif}
.stepper b{font-family:'Cormorant Garamond',serif;font-size:18px;color:var(--heading);min-width:14px}
.tally{text-align:center;margin:0 0 6px}
.tally b{display:block;font-family:'Cormorant Garamond',serif;font-size:32px;
  color:var(--ink-gold);font-weight:400;line-height:1.2}
.tally span{font-size:12px;color:var(--body);opacity:.85}
.ok{color:#4E7A54;font-size:12.5px;margin-top:14px;text-align:center}

/* wishes */
.wish{text-align:right;padding:14px 15px 14px 12px;border-right:2px solid var(--hair);
  background:<?= $fade($accent, 6) ?>;margin:10px 0}
.wish b{display:block;font-size:12px;color:var(--ink-gold);margin-bottom:5px;font-weight:400;
  font-family:'Amiri',serif;word-spacing:.12em}
.wish span{font-size:15px;line-height:1.9;color:var(--heading);font-style:italic}

/* gift */
.acct{font-family:'Cormorant Garamond',serif;font-size:19px;letter-spacing:.12em;
  color:var(--heading);margin:0 0 18px;direction:ltr;word-break:break-all}

footer{text-align:center;padding:14px 0 34px;color:var(--body);font-size:11px}
footer .mark{font-size:11.5px;color:var(--ink-gold);margin-top:11px}
footer a{color:var(--ink-gold);text-decoration:none}

/* ---------- bottom rail ---------- */
.bar{position:fixed;left:14px;right:14px;bottom:14px;z-index:50;display:flex;
  max-width:calc(var(--sheet) - 28px);margin:0 auto;padding:9px 6px;
  background:rgba(252,250,245,.92);
  -webkit-backdrop-filter:blur(18px) saturate(1.2);backdrop-filter:blur(18px) saturate(1.2);
  border:1px solid var(--hair-soft);box-shadow:0 12px 30px rgba(46,38,24,.18)}
.bar a{flex:1;display:flex;flex-direction:column;align-items:center;gap:5px;
  text-decoration:none;color:var(--body);font-size:11px;padding:3px 0;
  transition:color .3s ease;position:relative}
.bar a svg{width:17px;height:17px;fill:none;stroke:currentColor;stroke-width:1.15;
  stroke-linecap:round;stroke-linejoin:round}
.bar a.on{color:var(--ink-gold)}
.bar a.on:before{content:'';position:absolute;top:-9px;width:16px;height:1px;background:var(--ink-gold)}

@media (prefers-reduced-motion:reduce){
  *{animation:none!important;transition-duration:.01ms!important}
  .up{opacity:1;transform:none}
}
</style>
<noscript><style>
  /* Without scripting the envelope would trap the page for good, and the
     reveal would never fire. Show the invitation outright instead. */
  #env{display:none}
  .plate,.up{opacity:1!important;transform:none!important}
</style></noscript>
</head>
<body>

<div id="field"><b></b><i></i></div>
<div id="grain"></div>

<!-- Sealed envelope, tap to open -->
<div id="env" role="button" tabindex="0" aria-label="اضغط لفتح الدعوة">
  <div class="envelope">
    <div class="paper ebody"></div>
    <i class="fold l"></i><i class="fold r"></i><i class="fold b"></i>
    <div class="paper flap"></div>
    <div class="seal"><span class="latin"><?= $e($mono) ?></span></div>
  </div>
  <div class="tap"><em></em><span class="lbl">اضغط لفتح الدعوة</span></div>
</div>

<div id="shell">

<section class="hero" id="top">
  <div class="art"></div>
  <div class="tint"></div>
  <div class="fx <?= $e(in_array($anim, ['petals','arabesque'], true) ? $anim : '') ?>">
    <?php
      // Deterministic scatter — a seeded list beats rand() so the composition
      // is the same on every load and never clumps.
      $seeds = [[6,13,26,0],[18,7,31,3],[31,19,23,6],[44,9,29,1.5],[57,15,34,4],
                [69,8,25,7],[81,17,30,2],[92,11,27,5],[13,21,36,8],[38,12,24,9],
                [63,20,33,1],[86,14,28,6.5]];
      foreach ($seeds as $s) {
          printf('<b style="left:%d%%;width:%dpx;height:%dpx;animation-duration:%ds;animation-delay:-%ss"></b>',
                 $s[0], $s[1], $s[1], $s[2], $s[3]);
      }
    ?>
  </div>
  <article class="plate">
    <div class="plate-in">
      <div class="crest up"><div class="ring"><span class="latin"><?= $e($mono) ?></span></div></div>
      <p class="kicker lbl up">دعوة زفاف</p>

      <div class="names">
        <h1 class="nm display up"><?= $e($groom) ?></h1>
        <div class="amp up"><b>&amp;</b></div>
        <h1 class="nm display up"><?= $e($bride) ?></h1>
      </div>

      <?php if ($ts): ?>
      <p class="dateline up">
        <span class="lbl"><?= $e($dayNm) ?></span><i></i>
        <span class="big display"><?= $e($when) ?></span>
        <?php if ($clock): ?><i></i><span class="latin" style="font-size:13.5px"><?= $e($clock) ?></span><?php endif; ?>
      </p>
      <?php endif; ?>
    </div>
  </article>

  <a class="cue lbl" href="#date"><em></em>مرّر</a>
</section>
<div class="fade"></div>

<main>
  <?php if ($ts): ?>
  <div class="sec up" id="date" style="margin-top:24px">
    <p class="eyebrow lbl">العدّ التنازلي</p>
    <div class="card ruled" style="padding:26px 12px">
      <div class="count">
        <div><b id="cd">0</b><span class="lbl">يوم</span></div>
        <div><b id="ch">0</b><span class="lbl">ساعة</span></div>
        <div><b id="cm">0</b><span class="lbl">دقيقة</span></div>
        <div><b id="cs">0</b><span class="lbl">ثانية</span></div>
      </div>
    </div>
    <?php if ($gcal): ?>
    <a class="cal lbl" href="<?= $e($gcal) ?>" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24"><rect x="3.5" y="5" width="17" height="15.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/></svg>
      أضف إلى التقويم
    </a>
    <?php endif; ?>
  </div>
  <?php endif; ?>

  <?php if ($msg): ?>
    <div class="orn up"><?= $sprig ?></div>
    <div class="sec up"><p class="quote"><?= nl2br($e($msg)) ?></p></div>
  <?php endif; ?>

  <?php if ($venue): ?>
    <div class="orn up"><?= $sprig ?></div>
    <div class="sec up" id="place">
      <p class="eyebrow lbl">المكان</p>
      <div class="pinwrap">
        <svg viewBox="0 0 24 24"><path d="M12 21.5s7-6.1 7-11.5a7 7 0 1 0-14 0c0 5.4 7 11.5 7 11.5z"/><circle cx="12" cy="10" r="2.6"/></svg>
      </div>
      <p class="venue-name display"><?= $e($venue) ?></p>
      <?php if ($mapUrl): ?>
        <p style="margin-top:22px">
          <a class="btn" href="<?= $e($mapUrl) ?>" target="_blank" rel="noopener">
            <svg viewBox="0 0 24 24"><path d="M9 3.5 3.5 6v14.5L9 18l6 2.5 5.5-2.5V3.5L15 6z"/><path d="M9 3.5V18M15 6v14.5"/></svg>
            فتح الخريطة
          </a>
        </p>
      <?php endif; ?>
    </div>
  <?php endif; ?>

  <?php if ($gallery): ?>
    <div class="orn up"><?= $sprig ?></div>
    <div class="sec up" id="photos">
      <p class="eyebrow lbl">معرض الصور</p>
      <h2 class="display">لحظاتنا الجميلة</h2>
      <div class="gal" style="margin-top:22px">
        <?php foreach ($gallery as $g): ?>
          <figure><img src="<?= $e($g) ?>" alt="" loading="lazy"></figure>
        <?php endforeach; ?>
      </div>
    </div>
  <?php endif; ?>

  <div class="orn up"><?= $sprig ?></div>
  <div class="sec up" id="rsvp">
    <p class="eyebrow lbl">يسعدنا وجودكم</p>
    <h2 class="display">تأكيد الحضور</h2>
    <div class="card ruled" style="margin-top:22px">
      <div class="tally">
        <b id="conf"><?= $conf ?></b>
        <span class="lbl">تأكيد حضور</span>
      </div>
      <?php if (! $open): ?>
        <p style="text-align:center;margin:18px 0 4px;font-size:14px">أُغلق تأكيد الحضور لهذه الدعوة.</p>
      <?php else: ?>
      <form id="rsvpForm" onsubmit="return sendRsvp(event)" style="margin-top:18px">
        <div class="field">
          <label class="lbl">الاسم</label>
          <input name="name" placeholder="الاسم الكامل" required maxlength="120">
        </div>
        <div class="choices">
          <button type="button" id="yes" aria-pressed="false" onclick="pick(true)">سأحضر</button>
          <button type="button" id="no"  aria-pressed="false" onclick="pick(false)">أعتذر</button>
        </div>
        <div class="stepper" id="plusWrap" hidden>
          <span>عدد المرافقين</span>
          <span class="ctl">
            <button type="button" onclick="bump(-1)" aria-label="أقل">−</button>
            <b id="plus">0</b>
            <button type="button" onclick="bump(1)" aria-label="أكثر">+</button>
          </span>
        </div>
        <div class="field">
          <label class="lbl">ملاحظة</label>
          <input name="notes" placeholder="اختياري" maxlength="500">
        </div>
        <button class="btn solid" type="submit">إرسال الرد</button>
        <p class="ok" id="rsvpOk" hidden>تم تسجيل ردّك، شكرًا لك</p>
      </form>
      <?php endif; ?>
    </div>
  </div>

  <div class="orn up"><?= $sprig ?></div>
  <div class="sec up" id="wishes">
    <p class="eyebrow lbl">شاركونا فرحتنا</p>
    <h2 class="display">سجل التهاني</h2>
    <div class="card ruled" style="margin-top:22px">
      <form onsubmit="return sendWish(event)">
        <div class="field">
          <label class="lbl">الاسم</label>
          <input name="name" placeholder="اسمك" required maxlength="120">
        </div>
        <div class="field">
          <label class="lbl">التهنئة</label>
          <textarea name="body" rows="2" placeholder="اكتب كلمة طيبة…" required maxlength="1000"></textarea>
        </div>
        <button class="btn solid" type="submit">نشر التهنئة</button>
      </form>
      <div id="wishList" style="margin-top:20px">
        <?php foreach ($wishes as $w): ?>
          <div class="wish"><b><?= $e($w['name']) ?></b><span><?= $e($w['body']) ?></span></div>
        <?php endforeach; ?>
      </div>
    </div>
  </div>

  <?php if ($gift): ?>
    <div class="orn up"><?= $sprig ?></div>
    <div class="sec up">
      <p class="eyebrow lbl">الهدايا والحصالة</p>
      <div class="card ruled" style="margin-top:18px">
        <p class="acct"><?= $e($gift) ?></p>
        <button class="btn" type="button"
          onclick="navigator.clipboard.writeText(<?= json_encode($gift) ?>);this.textContent='تم النسخ'">نسخ المعلومات</button>
      </div>
    </div>
  <?php endif; ?>

  <footer>
    <div class="orn" style="margin:44px 0 22px"><?= $sprig ?></div>
    <div style="font-size:15px;color:var(--heading)" class="display"><?= $e($groom) ?> &amp; <?= $e($bride) ?></div>
    <div class="mark lbl">دعوة من أفراحنا</div>
  </footer>
</main>

<nav class="bar">
  <a href="#rsvp" data-t="rsvp"><svg viewBox="0 0 24 24"><path d="M12 20.2S4.4 15.3 4.4 10.1A4.4 4.4 0 0 1 12 7.2a4.4 4.4 0 0 1 7.6 2.9c0 5.2-7.6 10.1-7.6 10.1z"/></svg>الحضور</a>
  <a href="#place" data-t="place"><svg viewBox="0 0 24 24"><path d="M12 21.5s7-6.1 7-11.5a7 7 0 1 0-14 0c0 5.4 7 11.5 7 11.5z"/><circle cx="12" cy="10" r="2.4"/></svg>المكان</a>
  <a href="#photos" data-t="photos"><svg viewBox="0 0 24 24"><rect x="3.5" y="5" width="17" height="14"/><path d="m3.5 15.5 4.5-4 4 3.5 3.5-3 5 4.5"/><circle cx="9" cy="9.5" r="1.4"/></svg>الصور</a>
  <a href="#date" data-t="date"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.2"/><path d="M12 7.4V12l3.1 2"/></svg>الموعد</a>
  <a href="#wishes" data-t="wishes"><svg viewBox="0 0 24 24"><rect x="3.5" y="5.5" width="17" height="13"/><path d="m3.5 7 8.5 6.2L20.5 7"/></svg>التهاني</a>
</nav>

</div><!-- /#shell -->

<div id="lb" onclick="this.classList.remove('on')"><img alt=""></div>

<script>
const CODE = <?= json_encode($code) ?>;
const API  = <?= json_encode($api) ?>;

/* Envelope: open on tap, and remember it so a reload does not repeat it.
   The hero reveal is held back until the flap is down, so the names are the
   first thing seen after the seal breaks rather than a page already loaded. */
/* Storage throws rather than returns null in some in-app browsers, and an
   envelope that cannot remember being opened is better than a blank page. */
function remembered(key, set) {
  try {
    if (set) { sessionStorage.setItem(key, '1'); return true; }
    return !!sessionStorage.getItem(key);
  } catch (e) { return false; }
}

(function () {
  var env  = document.getElementById('env');
  var hero = document.querySelectorAll('.hero .up');
  function reveal() {
    document.body.classList.add('revealed');
    hero.forEach(function (el, i) {
      setTimeout(function () { el.classList.add('in'); }, 260 + i * 170);
    });
  }
  if (!env || remembered('opened-' + CODE)) {
    if (env) env.remove();
    reveal();
    return;
  }
  document.body.style.overflow = 'hidden';
  var opening = false;
  function unseal() {
    if (opening) return;
    opening = true;
    env.classList.add('open');
    setTimeout(function () {
      env.classList.add('gone');
      document.body.style.overflow = '';
      remembered('opened-' + CODE, true);
      reveal();
      setTimeout(function () { env.remove(); }, 900);
    }, 1200);
  }
  env.addEventListener('click', unseal);
  env.addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); unseal(); }
  });
})();

/* Everything below the fold arrives as it is scrolled to. */
(function () {
  var io = new IntersectionObserver(function (rows) {
    rows.forEach(function (r) { if (r.isIntersecting) { r.target.classList.add('in'); io.unobserve(r.target); } });
  }, { rootMargin: '0px 0px -12% 0px' });
  document.querySelectorAll('main .up').forEach(function (el) { io.observe(el); });
})();

/* Which section the rail is pointing at. */
(function () {
  var links = {};
  document.querySelectorAll('.bar a').forEach(function (a) { links[a.dataset.t] = a; });
  var io = new IntersectionObserver(function (rows) {
    rows.forEach(function (r) {
      var a = links[r.target.id];
      if (a) a.classList.toggle('on', r.isIntersecting);
    });
  }, { rootMargin: '-45% 0px -45% 0px' });
  ['date', 'place', 'photos', 'rsvp', 'wishes'].forEach(function (id) {
    var el = document.getElementById(id);
    if (el) io.observe(el);
  });
})();

/* Gallery lightbox */
document.querySelectorAll('.gal figure').forEach(function (f) {
  f.addEventListener('click', function () {
    var lb = document.getElementById('lb');
    lb.querySelector('img').src = f.querySelector('img').src;
    lb.classList.add('on');
  });
});

/* Countdown */
<?php if ($iso): ?>
(function () {
  var target = new Date(<?= json_encode($iso) ?>).getTime();
  function tick() {
    var diff = Math.max(0, target - Date.now()), s = Math.floor(diff / 1000);
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600),
        m = Math.floor(s % 3600 / 60), x = s % 60;
    var set = function (id, v) {
      var el = document.getElementById(id);
      if (el && el.textContent !== String(v)) el.textContent = v;
    };
    set('cd', d); set('ch', h); set('cm', m); set('cs', x);
  }
  tick(); setInterval(tick, 1000);
})();
<?php endif; ?>

/* A stable id for this browser, so a guest can correct their own reply
   instead of creating a second one. */
function token() {
  var t = localStorage.getItem('afrahna-guest');
  if (!t) {
    t = 'g' + Math.random().toString(36).slice(2) + Date.now().toString(36);
    localStorage.setItem('afrahna-guest', t);
  }
  return t;
}

var attending = null, plus = 0;
function pick(v) {
  attending = v;
  document.getElementById('yes').setAttribute('aria-pressed', v ? 'true' : 'false');
  document.getElementById('no').setAttribute('aria-pressed', v ? 'false' : 'true');
  document.getElementById('plusWrap').hidden = !v;
}
function bump(n) {
  plus = Math.max(0, Math.min(50, plus + n));
  document.getElementById('plus').textContent = plus;
}

async function sendRsvp(ev) {
  ev.preventDefault();
  if (attending === null) { alert('اختر الحضور أو الاعتذار'); return false; }
  var f = ev.target;
  var res = await fetch(API + '/invitations/public/' + CODE + '/rsvp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({
      name: f.name.value, attending: attending, plus_ones: plus,
      notes: f.notes.value, token: token()
    })
  });
  if (res.ok) {
    var j = await res.json();
    document.getElementById('conf').textContent = j.confirmed_count;
    document.getElementById('rsvpOk').hidden = false;
  } else {
    alert('تعذّر الإرسال، حاول مرة أخرى');
  }
  return false;
}

async function sendWish(ev) {
  ev.preventDefault();
  var f = ev.target;
  var res = await fetch(API + '/invitations/public/' + CODE + '/wish', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({ name: f.name.value, body: f.body.value })
  });
  if (res.ok) {
    var j = await res.json();
    var list = document.getElementById('wishList');
    list.textContent = '';
    (j.wishes || []).forEach(function (w) {
      var d = document.createElement('div');
      d.className = 'wish';
      var b = document.createElement('b'), s = document.createElement('span');
      b.textContent = w.name; s.textContent = w.body;
      d.appendChild(b); d.appendChild(s);
      list.appendChild(d);
    });
    f.body.value = '';
  }
  return false;
}
</script>
</body>
</html>
