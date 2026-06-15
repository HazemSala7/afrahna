<?php
// Self-destructing opcache reset.
header('Content-Type: text/plain; charset=utf-8');
$ok = function_exists('opcache_reset') ? @opcache_reset() : false;
echo "opcache_reset: " . ($ok ? 'OK' : 'unavailable') . "\n";
@unlink(__FILE__);
echo "self-deleted\n";
