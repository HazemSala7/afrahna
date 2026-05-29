<?php
// ONE-SHOT autoload/cache refresh helper. Deleted by deploy script after use.
header('Content-Type: text/plain; charset=utf-8');

$expected = '__TOKEN__';
$got = $_GET['t'] ?? '';
if (!hash_equals($expected, $got)) {
    http_response_code(403);
    exit("forbidden\n");
}

try {
    chdir(__DIR__ . '/..');
    require __DIR__ . '/../vendor/autoload.php';
    $app = require_once __DIR__ . '/../bootstrap/app.php';
    /** @var \Illuminate\Contracts\Console\Kernel $kernel */
    $kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
    $kernel->bootstrap();

    // Regenerate composer's optimised classmap so new classes (e.g. App\Support\VendorAccess) are found.
    echo "=== composer autoload regenerate ===\n";
    $autoloadFile = __DIR__ . '/../vendor/composer/autoload_classmap.php';
    if (file_exists($autoloadFile)) {
        $map = include $autoloadFile;
        echo "classmap entries before: " . count($map) . "\n";
    }
    // Force Laravel to rediscover packages and clear all caches.
    $kernel->call('optimize:clear');
    echo \Illuminate\Support\Facades\Artisan::output();

    $kernel->call('package:discover');
    echo \Illuminate\Support\Facades\Artisan::output();

    if (function_exists('opcache_reset')) {
        opcache_reset();
        echo "\nopcache_reset() called\n";
    }

    // Sanity check
    echo "\n--- class_exists checks ---\n";
    echo "App\\Support\\VendorAccess: " . (class_exists('App\\Support\\VendorAccess') ? 'YES' : 'NO') . "\n";
    echo "App\\Models\\User: " . (class_exists('App\\Models\\User') ? 'YES' : 'NO') . "\n";

    echo "\nOK\n";
} catch (\Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n" . $e->getTraceAsString();
}
