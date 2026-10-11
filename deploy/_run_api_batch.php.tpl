<?php
// ONE-SHOT runner for a small API deploy. Proves the changed classes load on
// the server's PHP, applies only the named migration (if any), and checks
// the columns it was meant to add. Token-protected; the deploy script
// deletes it afterwards.
header('Content-Type: text/plain; charset=utf-8');

$expected = '__TOKEN__';
$got = $_GET['t'] ?? '';
if (!hash_equals($expected, $got)) {
    http_response_code(403);
    exit("forbidden\n");
}

$classes   = __CLASSES__;
$migration = '__MIGRATION__';
$columns   = __COLUMNS__;

try {
    chdir(__DIR__ . '/..');
    require __DIR__ . '/../vendor/autoload.php';
    $app = require_once __DIR__ . '/../bootstrap/app.php';
    /** @var \Illuminate\Contracts\Console\Kernel $kernel */
    $kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
    $kernel->bootstrap();

    echo "=== classes load ===\n";
    foreach ($classes as $cls) {
        echo $cls, ': ', class_exists($cls) ? 'ok' : 'MISSING', "\n";
    }

    if ($migration !== '') {
        echo "\n=== migrate --force --path=$migration ===\n";
        $status = $kernel->call('migrate', ['--force' => true, '--path' => $migration]);
        echo \Illuminate\Support\Facades\Artisan::output();
        echo "exit: $status\n";
    }

    if ($columns) {
        echo "\n=== columns ===\n";
        foreach ($columns as $spec) {
            [$table, $col] = explode('.', $spec, 2);
            echo $spec, ': ', \Illuminate\Support\Facades\Schema::hasColumn($table, $col) ? 'present' : 'ABSENT', "\n";
        }
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
