<?php
// Public share/landing page for a vendor profile:  https://afrahna.co/v/{id}
// - Renders a preview (Open Graph tags for WhatsApp/social).
// - Tries to open the app via the custom scheme (afrahna://vendor/{id}).
// - Falls back to the app store download.

$uri = $_SERVER['REQUEST_URI'] ?? '';
if (preg_match('#/v/(\d+)#', $uri, $m)) {
    $id = $m[1];
} else {
    $id = preg_replace('/\D/', '', $_GET['id'] ?? '');
}

$vendor = null;
if ($id !== '') {
    $ctx = stream_context_create(['http' => ['timeout' => 6]]);
    $json = @file_get_contents("https://afrahna.co/admin/api/v1/vendors/$id", false, $ctx);
    if ($json) {
        $d = json_decode($json, true);
        $vendor = $d['data'] ?? $d;
    }
}

$name  = $vendor['name_ar'] ?? $vendor['name_en'] ?? 'أفراحنا';
$logo  = $vendor['logo'] ?? '';
$cover = $vendor['cover_image'] ?? '';
$desc  = trim($vendor['description_ar'] ?? '') ?: 'اكتشف هذا المعلن على تطبيق أفراحنا — قاعات، فساتين، تجهيزات أعراس والمزيد.';
$cat   = $vendor['category']['name_ar'] ?? '';
$city  = $vendor['city']['name_ar'] ?? '';
$ogImg = $cover ?: $logo;

$scheme   = "afrahna://vendor/$id";
$play     = "https://play.google.com/store/apps/details?id=afrahna.sala7.neurex";
$appstore = "https://apps.apple.com/app/id6772547042";

$e = fn ($s) => htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
?>
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= $e($name) ?> — أفراحنا</title>
<meta property="og:title" content="<?= $e($name) ?> — أفراحنا">
<meta property="og:description" content="<?= $e($desc) ?>">
<?php if ($ogImg): ?><meta property="og:image" content="<?= $e($ogImg) ?>"><?php endif; ?>
<meta property="og:type" content="website">
<meta name="theme-color" content="#8B5A3C">
<style>
  :root { --brand:#B8835A; --brand-dark:#8B5A3C; --cream:#FBF6F0; --ink:#2A2320; --muted:#8b7d70; }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:'Segoe UI',Tahoma,system-ui,sans-serif; background:var(--cream); color:var(--ink);
         min-height:100vh; display:flex; align-items:center; justify-content:center; padding:18px; }
  .card { width:100%; max-width:440px; background:#fff; border-radius:26px; overflow:hidden;
          box-shadow:0 18px 50px rgba(0,0,0,.12); }
  .cover { height:150px; background:linear-gradient(135deg,#D9B68A,#B8835A,#8B5A3C); background-size:cover;
           background-position:center; }
  .body { padding:0 22px 24px; text-align:center; margin-top:-52px; }
  .logo { width:104px; height:104px; border-radius:50%; border:4px solid #fff; object-fit:cover;
          background:#eee; box-shadow:0 8px 20px rgba(0,0,0,.15); margin:0 auto; display:block; }
  .logo.ph { display:flex; align-items:center; justify-content:center; font-size:40px; color:#fff;
             background:linear-gradient(135deg,#D9B68A,#8B5A3C); }
  h1 { font-size:22px; margin-top:14px; font-weight:800; }
  .meta { color:var(--muted); font-size:13.5px; margin-top:6px; }
  .desc { color:#5c5148; font-size:14px; line-height:1.8; margin-top:14px; max-height:120px; overflow:hidden; }
  .btns { margin-top:22px; display:flex; flex-direction:column; gap:10px; }
  .btn { display:flex; align-items:center; justify-content:center; gap:8px; padding:14px; border-radius:16px;
         font-weight:800; font-size:15px; text-decoration:none; border:none; cursor:pointer; }
  .btn-primary { background:linear-gradient(135deg,var(--brand),var(--brand-dark)); color:#fff;
                 box-shadow:0 8px 18px rgba(139,90,60,.35); }
  .btn-store { background:#fff; color:var(--ink); border:1.5px solid #eadfd4; }
  .stores { display:flex; gap:10px; }
  .stores .btn { flex:1; font-size:13.5px; padding:12px; }
  .hint { color:var(--muted); font-size:12px; margin-top:16px; }
  .brand { margin-top:18px; font-weight:900; color:var(--brand-dark); letter-spacing:.5px; }
</style>
</head>
<body>
  <div class="card">
    <div class="cover" <?= $cover ? 'style="background-image:url(\'' . $e($cover) . '\')"' : '' ?>></div>
    <div class="body">
      <?php if ($logo): ?>
        <img class="logo" src="<?= $e($logo) ?>" alt="">
      <?php else: ?>
        <div class="logo ph">🏪</div>
      <?php endif; ?>
      <h1><?= $e($name) ?></h1>
      <?php if ($cat || $city): ?>
        <div class="meta"><?= $e(trim($cat . ($cat && $city ? ' · ' : '') . $city)) ?></div>
      <?php endif; ?>
      <p class="desc"><?= nl2br($e($desc)) ?></p>

      <div class="btns">
        <button class="btn btn-primary" onclick="openApp()">📱 افتح في تطبيق أفراحنا</button>
        <div class="stores">
          <a class="btn btn-store" href="<?= $e($play) ?>">▶ Google Play</a>
          <a class="btn btn-store" href="<?= $e($appstore) ?>"> App Store</a>
        </div>
      </div>
      <div class="hint">إذا كان التطبيق مثبّتًا سيفتح صفحة المحل مباشرة، وإلا حمّله من المتجر.</div>
      <div class="brand">أفراحنا</div>
    </div>
  </div>

<script>
  var SCHEME = <?= json_encode($scheme) ?>;
  var PLAY = <?= json_encode($play) ?>;
  var APPSTORE = <?= json_encode($appstore) ?>;
  var ua = navigator.userAgent || '';
  var isIOS = /iPhone|iPad|iPod/i.test(ua);
  var isAndroid = /Android/i.test(ua);

  function storeUrl(){ return isIOS ? APPSTORE : PLAY; }

  function openApp(){
    var t = Date.now();
    // Attempt to open the app via its custom scheme.
    window.location.href = SCHEME;
    // If still here after a moment, the app isn't installed → go to the store.
    setTimeout(function(){
      if (Date.now() - t < 2200) window.location.href = storeUrl();
    }, 1500);
  }

  // Auto-attempt once on mobile so a tap on the shared link jumps into the app.
  if (isIOS || isAndroid) { setTimeout(openApp, 400); }
</script>
</body>
</html>
