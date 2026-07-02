<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Health check route
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toISOString(),
        'service' => 'han-tech-backend',
        'environment' => app()->environment()
    ]);
});

// Database check route
Route::get('/db-check', function () {
    try {
        $result = DB::select('SELECT 1 as connected');
        return response()->json([
            'status' => 'success',
            'message' => 'Database connected successfully!',
            'data' => $result
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'status' => 'error',
            'message' => 'Database connection failed',
            'error' => $e->getMessage()
        ], 500);
    }
});

// Welcome route
Route::get('/', function () {
    return response()->json([
        'message' => 'Han-Tech API',
        'version' => '1.0.0',
        'status' => 'operational',
        'endpoints' => [
            '/api/health' => 'Health check',
            '/api/db-check' => 'Database connection test'
        ]
    ]);
});

// Protected routes (example)
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
});