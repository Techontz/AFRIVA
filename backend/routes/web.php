<?php

use Illuminate\Support\Facades\Route;

// This host only serves the API (see routes/api.php); the website is the separate Next.js app.
// The index is a static JSON document: skip the "web" group (sessions, cookies, CSRF) so it never touches
// the session store or the database.
Route::get('/', fn () => response()->json([
    'name' => config('app.name').' API',
    'version' => 'v1',
    'base_url' => url('/api/v1'),
]))->withoutMiddleware('web');
