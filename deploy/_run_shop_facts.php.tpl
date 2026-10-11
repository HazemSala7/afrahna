<?php
// ONE-SHOT runner for the shop-page facts deploy (working_hours, delivery_note,
// photos/videos counts, points/invitees). Applies only the one new migration,
// then proves the changed classes load on the server's PHP. Token-protected;
// deleted by the deploy script afterwards.
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

    echo "=== classes load ===\n";
    foreach ([
        \App\Models\Vendor::class,
        \App\Http\Controllers\Api\VendorController::class,
        \App\Http\Controllers\Api\PointController::class,
    ] as $cls) {
        echo $cls, ': ', class_exists($cls) ? 'ok' : 'MISSING', "\n";
    }
    echo "routes/api.php: ", (strpos(file_get_contents(__DIR__ . '/../routes/api.php'), 'points/invitees') !== false ? 'has points/invitees' : 'NO points/invitees'), "\n\n";

    echo "=== migrate --force --path=database/migrations/2026_10_10_000001_add_profile_facts_to_vendors.php ===\n";
    $status = $kernel->call('migrate', [
        '--force' => true,
        '--path' => 'database/migrations/2026_10_10_000001_add_profile_facts_to_vendors.php',
    ]);
    echo \Illuminate\Support\Facades\Artisan::output();
    echo "exit: $status\n\n";

    echo "=== columns ===\n";
    foreach (['working_hours', 'delivery_note'] as $col) {
        echo $col, ': ', \Illuminate\Support\Facades\Schema::hasColumn('vendors', $col) ? 'present' : 'ABSENT', "\n";
    }

    echo "\n=== optimize:clear ===\n";
    $kernel->call('optimize:clear');
    echo \Illuminate\Support\Facades\Artisan::output();
    if (function_exists('opcache_reset')) {
        opcache_reset();
        echo "opcache_reset() called\n";
    }
    echo "\nOK\n";
} catch (\Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n" . $e->getTraceAsString();
}
