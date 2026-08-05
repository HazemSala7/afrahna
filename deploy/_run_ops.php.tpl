<?php
// ONE-SHOT ops runner: apply the auto-growth rate migration and repair reels
// whose MP4 container has a duplicated `moov` header.
// Token-gated, and DELETED immediately after a successful run.
header('Content-Type: text/plain; charset=utf-8');

$expected = '__TOKEN__';
$got = $_GET['t'] ?? '';
if (!hash_equals($expected, $got)) {
    http_response_code(403);
    exit("forbidden\n");
}

@set_time_limit(0);
@ini_set('max_execution_time', '0');

try {
    chdir(__DIR__ . '/..');
    require __DIR__ . '/../vendor/autoload.php';
    $app = require_once __DIR__ . '/../bootstrap/app.php';
    /** @var \Illuminate\Contracts\Console\Kernel $kernel */
    $kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
    $kernel->bootstrap();

    $step = $_GET['step'] ?? 'all';

    if ($step === 'all' || $step === 'migrate') {
        echo "=== php artisan migrate --force ===\n";
        $status = $kernel->call('migrate', ['--force' => true]);
        echo \Illuminate\Support\Facades\Artisan::output();
        echo "exit: $status\n\n";
    }

    if ($step === 'all' || $step === 'scan') {
        echo "=== php artisan reels:repair --dry-run ===\n";
        $kernel->call('reels:repair', ['--dry-run' => true]);
        echo \Illuminate\Support\Facades\Artisan::output();
        echo "\n";
    }

    if ($step === 'repair') {
        $limit = (string) (int) ($_GET['limit'] ?? 2);
        echo "=== php artisan reels:repair --limit={$limit} ===\n";
        $kernel->call('reels:repair', ['--limit' => $limit]);
        echo \Illuminate\Support\Facades\Artisan::output();
        echo "\n";
    }

    if ($step === 'all' || $step === 'clear') {
        echo "=== php artisan optimize:clear ===\n";
        $kernel->call('optimize:clear');
        echo \Illuminate\Support\Facades\Artisan::output();
    }

    if (function_exists('opcache_reset')) {
        opcache_reset();
        echo "\nopcache_reset() called\n";
    }
    echo "\nOK\n";
} catch (\Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n" . $e->getTraceAsString();
}
