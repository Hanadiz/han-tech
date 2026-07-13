// backend/routes/api.php
Route::get('/health', function () {
    return response()->json([
        'status' => 'healthy',
        'database' => DB::connection()->getPdo() ? true : false,
        'cache' => Cache::get('health_check', true),
        'queue' => Queue::size('default') < 1000,
        'timestamp' => now()->toISOString(),
    ]);
});