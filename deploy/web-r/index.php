<?php
// Public invite/referral landing page:  https://afrahna.co/r/{CODE}
//
// One link that works from every platform:
//   - app installed  → opens it via afrahna://invite/{CODE}
//   - Android        → Google Play
//   - iPhone/iPad    → App Store
//   - desktop        → shows the code to use on the phone
// The code is also copied to the clipboard, so a friend who installs the app
// first can paste it into the "كود دعوة صديق" field during sign-up.

$uri = $_SERVER['REQUEST_URI'] ?? '';
if (preg_match('#/r/([A-Za-z0-9]{3,16})#', $uri, $m)) {
    $code = strtoupper($m[1]);
} else {
    $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $_GET['code'] ?? ''));
}

$inviter = null;
if ($code !== '') {
    $ctx  = stream_context_create(['http' => ['timeout' => 6]]);
    $json = @file_get_contents("https://afrahna.co/admin/api/v1/referral/$code", false, $ctx);
    if ($json) {
        $d = json_decode($json, true);
        if (! empty($d['valid'])) $inviter = $d['name'] ?? null;
    }
}

$scheme   = "afrahna://invite/$code";
$play     = "https://play.google.com/store/apps/details?id=afrahna.sala7.neurex";
$appstore = "https://apps.apple.com/app/id6772547042";

$title = $inviter ? "$inviter يدعوك إلى أفراحنا" : 'دعوة للانضمام إلى أفراحنا';
$e = fn ($s) => htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= $e($title) ?></title>
<meta property="og:title" content="<?= $e($title) ?>">
<meta property="og:description" content="حمّل تطبيق أفراحنا وسجّل بكود الدعوة — كل ما يلزم مناسباتك في مكان واحد.">
<meta property="og:type" content="website">
<meta name="theme-color" content="#8B5A3C">
<style>
  :root { --brand:#B8835A; --brand-dark:#8B5A3C; --gold:#E0AE44; --cream:#FBF6F0; --ink:#2A2320; --muted:#8b7d70; }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:'Segoe UI',Tahoma,system-ui,sans-serif; background:var(--cream); color:var(--ink);
         min-height:100vh; display:flex; align-items:center; justify-content:center; padding:18px; }
  .card { width:100%; max-width:440px; background:#fff; border-radius:26px; overflow:hidden;
          box-shadow:0 18px 50px rgba(0,0,0,.12); text-align:center; }
  .top { background:linear-gradient(135deg,#E6B450,#B8835A,#8B5A3C); padding:30px 22px 26px; color:#fff; }
  .gift { font-size:46px; }
  h1 { font-size:20px; font-weight:800; margin-top:10px; line-height:1.5; }
  .sub { font-size:13.5px; opacity:.92; margin-top:6px; }
  .body { padding:24px 22px 26px; }
  .codebox { border:2px dashed #e3cdb2; border-radius:18px; padding:14px; background:#fffaf3; }
  .codelabel { font-size:12px; color:var(--muted); }
  .code { font-size:30px; font-weight:900; letter-spacing:4px; color:var(--brand-dark); margin-top:4px;
          font-family:'Courier New',monospace; }
  .copied { font-size:12px; color:#1B9C5A; margin-top:6px; height:16px; font-weight:700; }
  .btns { margin-top:20px; display:flex; flex-direction:column; gap:10px; }
  .btn { display:flex; align-items:center; justify-content:center; gap:8px; padding:14px; border-radius:16px;
         font-weight:800; font-size:15px; text-decoration:none; border:none; cursor:pointer; width:100%; }
  .btn-primary { background:linear-gradient(135deg,var(--brand),var(--brand-dark)); color:#fff;
                 box-shadow:0 8px 18px rgba(139,90,60,.35); }
  .btn-store { background:#fff; color:var(--ink); border:1.5px solid #eadfd4; }
  .stores { display:flex; gap:10px; }
  .stores .btn { flex:1; font-size:13.5px; padding:12px; }
  .steps { text-align:right; margin-top:20px; border-top:1px solid #f0e6da; padding-top:16px; }
  .steps h2 { font-size:13.5px; color:var(--ink); margin-bottom:8px; }
  .steps li { color:var(--muted); font-size:12.5px; line-height:2; margin-right:16px; }
  .brand { margin-top:18px; font-weight:900; color:var(--brand-dark); letter-spacing:.5px; }
  .bad { color:#C1452B; font-size:13px; margin-top:10px; }
</style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="gift">🎁</div>
      <h1><?= $inviter ? $e($inviter) . ' يدعوك إلى أفراحنا' : 'دعوة للانضمام إلى أفراحنا' ?></h1>
      <div class="sub">كل ما يلزم مناسباتك في مكان واحد</div>
    </div>

    <div class="body">
      <?php if ($code === ''): ?>
        <div class="bad">رابط الدعوة غير مكتمل.</div>
      <?php else: ?>
        <div class="codebox">
          <div class="codelabel">كود الدعوة</div>
          <div class="code" id="code"><?= $e($code) ?></div>
          <div class="copied" id="copied"></div>
        </div>

        <div class="btns">
          <button class="btn btn-primary" onclick="openApp()">📱 افتح التطبيق وسجّل الآن</button>
          <div class="stores">
            <a class="btn btn-store" href="<?= $e($play) ?>">▶ Google Play</a>
            <a class="btn btn-store" href="<?= $e($appstore) ?>"> App Store</a>
          </div>
        </div>

        <div class="steps">
          <h2>كيف تحصلان على النقاط؟</h2>
          <ol>
            <li>حمّل تطبيق أفراحنا من متجر هاتفك.</li>
            <li>افتح التطبيق و<strong>أنشئ حسابًا</strong> — النقاط لا تُحتسب بدون تسجيل.</li>
            <li>الكود منسوخ لك؛ إن لم يظهر تلقائيًا الصقه في خانة «كود دعوة صديق».</li>
          </ol>
        </div>
      <?php endif; ?>

      <div class="brand">أفراحنا</div>
    </div>
  </div>

<script>
  var SCHEME = <?= json_encode($scheme) ?>;
  var PLAY = <?= json_encode($play) ?>;
  var APPSTORE = <?= json_encode($appstore) ?>;
  var CODE = <?= json_encode($code) ?>;
  var ua = navigator.userAgent || '';
  var isIOS = /iPhone|iPad|iPod/i.test(ua) ||
              (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isAndroid = /Android/i.test(ua);

  function storeUrl(){ return isIOS ? APPSTORE : PLAY; }

  // Put the code on the clipboard so it survives the trip through the store:
  // install, open, paste. This is what makes the invite work even when the app
  // wasn't installed when the link was tapped.
  function copyCode(){
    if (!CODE) return;
    var done = function(){ var el = document.getElementById('copied'); if (el) el.textContent = '✓ تم نسخ الكود'; };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(CODE).then(done, function(){});
    } else {
      try {
        var ta = document.createElement('textarea');
        ta.value = CODE; document.body.appendChild(ta); ta.select();
        document.execCommand('copy'); document.body.removeChild(ta); done();
      } catch (e) {}
    }
  }

  function openApp(){
    if (!CODE) return;
    copyCode();
    var t = Date.now();
    window.location.href = SCHEME;
    // Still here a moment later → the app isn't installed, send them to the store.
    setTimeout(function(){
      if (Date.now() - t < 2200) window.location.href = storeUrl();
    }, 1500);
  }

  // Tell the server this invite link was opened, so the dashboard can show
  // invites that were seen but never completed. Fire-and-forget: a blocked or
  // failed beacon must never hold up opening the app.
  function trackVisit(){
    if (!CODE) return;
    try {
      fetch('https://afrahna.co/admin/api/v1/referral/' + encodeURIComponent(CODE) + '/visit',
            { method: 'POST', keepalive: true, headers: { 'Accept': 'application/json' } })
        .catch(function(){});
    } catch (e) {}
  }

  trackVisit();
  copyCode();
  // Auto-attempt on mobile so tapping the shared link jumps straight in.
  if (isIOS || isAndroid) { setTimeout(openApp, 500); }
</script>
</body>
</html>
