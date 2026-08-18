<?php
// ONE-SHOT cleanup: removes the throwaway account used to verify the rewards
// ladder on production, along with everything it created (likes, point
// counters, tokens, the "new user" admin notification).
//
// Scoped to a single user id, token-gated, and DELETED after it runs.
header('Content-Type: text/plain; charset=utf-8');

$expected = '__TOKEN__';
if (!hash_equals($expected, $_GET['t'] ?? '')) {
    http_response_code(403);
    exit("forbidden\n");
}

$userId = (int) ($_GET['user'] ?? 0);
$phone  = (string) ($_GET['phone'] ?? '');
if ($userId <= 0 || $phone === '') {
    http_response_code(400);
    exit("need user and phone\n");
}

try {
    chdir(__DIR__ . '/..');
    require __DIR__ . '/../vendor/autoload.php';
    $app = require_once __DIR__ . '/../bootstrap/app.php';
    $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

    $db = Illuminate\Support\Facades\DB::class;

    // Refuse to touch anything but the exact row that was created: the id and
    // the phone must both match, so a wrong id deletes nothing.
    $user = Illuminate\Support\Facades\DB::table('users')
        ->where('id', $userId)->where('phone', $phone)->first();

    // ?orphans=1 sweeps rows left behind by an earlier run that already
    // deleted the account. Every child table is keyed by user_id, so that is
    // safe without the phone match — but it must never delete a users row,
    // which is the thing the phone was guarding.
    $orphansOnly = ($_GET['orphans'] ?? '') === '1';
    if (!$user && !$orphansOnly) {
        http_response_code(404);
        exit("no user {$userId} with that phone — nothing deleted\n");
    }
    if (!$user) {
        echo "user {$userId} already gone — sweeping leftovers only\n\n";
    }

    $counts = [];
    foreach ([
        'post_likes'            => 'user_id',
        'user_point_progress'   => 'user_id',
        'point_rewards'         => 'user_id',
        'point_redemptions'     => 'user_id',
        'personal_access_tokens' => null,   // handled below (morph columns)
    ] as $table => $col) {
        if ($col === null) continue;
        if (!Illuminate\Support\Facades\Schema::hasTable($table)) continue;
        $counts[$table] = Illuminate\Support\Facades\DB::table($table)
            ->where($col, $userId)->delete();
    }

    $counts['personal_access_tokens'] = Illuminate\Support\Facades\DB::table('personal_access_tokens')
        ->where('tokenable_type', 'App\\Models\\User')
        ->where('tokenable_id', $userId)->delete();

    // The likes bumped each post's cached counter, so walk it back by one on
    // exactly the posts that were liked. NOT a recount from the pivot: the
    // displayed count also carries traffic-driven growth that has no rows
    // behind it, and a recount would erase it across the whole table.
    $posts = array_filter(array_map('intval', explode(',', (string) ($_GET['posts'] ?? ''))));
    if ($posts) {
        $counts['posts_decremented'] = Illuminate\Support\Facades\DB::table('posts')
            ->whereIn('id', $posts)->where('likes_count', '>', 0)
            ->decrement('likes_count');
    }

    if (Illuminate\Support\Facades\Schema::hasTable('notifications')) {
        // Two shapes to catch: rows addressed TO this member (user_id), and
        // admin rows merely ABOUT them, which carry the id inside the data
        // blob instead. Matching only the blob leaves every points message
        // behind as an orphan.
        $counts['notifications'] = Illuminate\Support\Facades\DB::table('notifications')
            ->where('user_id', $userId)
            ->orWhere('data', 'like', '%"user_id":' . $userId . '%')
            ->delete();
    }

    $counts['users'] = $user
        ? Illuminate\Support\Facades\DB::table('users')
            ->where('id', $userId)->where('phone', $phone)->delete()
        : 0;

    foreach ($counts as $k => $v) echo str_pad($k, 26) . " {$v}\n";
    echo "\nOK\n";
} catch (\Throwable $e) {
    http_response_code(500);
    echo "ERROR: " . $e->getMessage() . "\n";
}
