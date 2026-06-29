<?php
// ONE-SHOT: create/update the admin user (phone 123123123 / 123456) on prod.
// Auto-deleted by the deploy script after a successful run.
// Token-protected so a random visitor can't trigger it.
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

    $user = \App\Models\User::updateOrCreate(
        ['phone' => '123123123'],
        [
            'name'      => 'Admin',
            'email'     => 'admin123@afrahna.local',
            'password'  => \Illuminate\Support\Facades\Hash::make('123456'),
            'role'      => 'admin',
            'locale'    => 'ar',
            'is_active' => true,
        ]
    );

    echo "=== admin user upserted ===\n";
    echo "id:    {$user->id}\n";
    echo "phone: {$user->phone}\n";
    echo "role:  {$user->role}\n";
    echo "\nOK\n";
} catch (\Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n" . $e->getTraceAsString();
}
