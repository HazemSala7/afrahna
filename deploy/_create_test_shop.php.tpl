<?php
// ONE-SHOT: create (or refresh) the test shop-owner account on production, so
// the shop side of the app can be tried without touching a real owner's
// account. Token-protected; deleted by the deploy script after it runs.
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

    $phone = '0599990001';

    $user = \App\Models\User::updateOrCreate(
        ['phone' => $phone],
        [
            'name'      => 'محل تجريبي',
            'email'     => 'testshop@afrahna.local',
            'password'  => \Illuminate\Support\Facades\Hash::make('__PASSWORD__'),
            'role'      => 'vendor',
            'locale'    => 'ar',
            'is_active' => true,
        ]
    );

    // Somewhere real to hang the shop: the first category, and Hebron when
    // it exists, else the first city.
    $category = \App\Models\Category::query()->orderBy('id')->first();
    $city = \App\Models\City::query()->where('name_ar', 'like', '%الخليل%')->first()
        ?? \App\Models\City::query()->orderBy('id')->first();
    if (!$category) {
        throw new RuntimeException('no categories on this server');
    }

    $shop = \App\Models\Vendor::updateOrCreate(
        ['slug' => 'afrahna-test-shop'],
        [
            'user_id'        => $user->id,
            'category_id'    => $category->id,
            'city_id'        => $city?->id,
            'name_ar'        => 'محل تجريبي - أفراحنا',
            'name_en'        => 'Afrahna Test Shop',
            'description_ar' => 'حساب تجريبي لفريق أفراحنا لتجربة واجهة المحل. ليس محلاً حقيقياً.',
            'phone'          => $phone,
            'whatsapp'       => $phone,
            'address'        => 'الخليل',
            'working_hours'  => 'يومياً 9:00 ص - 10:00 م',
            'delivery_note'  => 'توصيل داخل الخليل',
            'is_active'      => true,
            'is_store'       => true,
        ]
    );

    echo "=== test shop owner ===\n";
    echo "user id:   {$user->id}\n";
    echo "phone:     {$user->phone}\n";
    echo "role:      {$user->role}\n";
    echo "shop id:   {$shop->id}\n";
    echo "shop:      {$shop->name_ar}\n";
    echo "category:  {$category->name_ar}\n";
    echo "city:      " . ($city?->name_ar ?? '-') . "\n";
    echo "\nOK\n";
} catch (\Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n" . $e->getTraceAsString();
}
