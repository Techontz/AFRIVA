<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\EpisodeController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\Studio;
use Illuminate\Support\Facades\Route;

/*
| Afriva REST API v1 — see SPEC.md §6. All responses: { data, meta? }; errors: { message, code, errors? }.
*/
Route::prefix('v1')->group(function () {

    // ---- Auth -------------------------------------------------------------
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:20,1');
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:30,1');

    // ---- Public catalogue (auth optional: token, if sent, personalises is_favorite / is_unlocked) ----
    Route::get('home', [CatalogController::class, 'home']);
    Route::get('categories', [CatalogController::class, 'categories']);
    Route::get('dramas', [CatalogController::class, 'dramas']);
    Route::get('dramas/rankings', [CatalogController::class, 'rankings']);
    Route::get('dramas/{slug}', [CatalogController::class, 'show']);
    Route::get('feed', [CatalogController::class, 'feed']);
    Route::get('plans', [CatalogController::class, 'plans']);
    Route::get('payment-methods', [CatalogController::class, 'paymentMethods']);
    Route::get('episodes/{id}/play', [EpisodeController::class, 'play'])->whereNumber('id');

    // ---- Payment provider webhooks (public) ----
    Route::post('payments/callback/{provider}', [PaymentController::class, 'callback']);

    // ---- Authenticated viewer ----
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('auth/me', [AuthController::class, 'me']);

        Route::post('episodes/{id}/unlock', [EpisodeController::class, 'unlock'])->whereNumber('id');
        Route::post('episodes/{id}/progress', [EpisodeController::class, 'progress'])->whereNumber('id');

        Route::post('checkout', [PaymentController::class, 'checkout']);
        Route::get('payments/{reference}', [PaymentController::class, 'show']);

        Route::get('me/subscription', [MeController::class, 'subscription']);
        Route::get('me/payments', [MeController::class, 'payments']);
        Route::get('me/history', [MeController::class, 'history']);
        Route::get('me/favorites', [MeController::class, 'favorites']);
        Route::post('me/favorites/{drama_id}', [MeController::class, 'toggleFavorite'])->whereNumber('drama_id');

        // ---- Super admin ----
        Route::prefix('admin')->middleware('role:super_admin')->group(function () {
            Route::get('dashboard', Admin\DashboardController::class);

            Route::get('companies/{company}/stats', [Admin\CompanyController::class, 'stats']);
            Route::apiResource('companies', Admin\CompanyController::class);
            Route::apiResource('plans', Admin\PlanController::class);
            Route::apiResource('categories', Admin\CategoryController::class);

            Route::get('dramas', [Admin\DramaController::class, 'index']);
            Route::post('dramas', [Admin\DramaController::class, 'store']);
            Route::get('dramas/{drama}', [Admin\DramaController::class, 'show'])->whereNumber('drama');
            Route::match(['put', 'patch'], 'dramas/{drama}', [Admin\DramaController::class, 'update'])->whereNumber('drama');
            Route::delete('dramas/{drama}', [Admin\DramaController::class, 'destroy'])->whereNumber('drama');
            Route::get('dramas/{drama}/episodes', [Admin\DramaController::class, 'episodes'])->whereNumber('drama');
            Route::post('dramas/{drama}/episodes', [Admin\DramaController::class, 'storeEpisode'])->whereNumber('drama');
            Route::get('dramas/{drama}/episodes/{episode}', [Admin\DramaController::class, 'showEpisode'])->whereNumber(['drama', 'episode']);
            Route::match(['put', 'patch'], 'dramas/{drama}/episodes/{episode}', [Admin\DramaController::class, 'updateEpisode'])->whereNumber(['drama', 'episode']);
            Route::delete('dramas/{drama}/episodes/{episode}', [Admin\DramaController::class, 'destroyEpisode'])->whereNumber(['drama', 'episode']);

            Route::get('payment-methods', [Admin\PaymentMethodController::class, 'index']);
            Route::get('payment-methods/{paymentMethod}', [Admin\PaymentMethodController::class, 'show']);
            Route::match(['put', 'patch'], 'payment-methods/{paymentMethod}', [Admin\PaymentMethodController::class, 'update']);

            Route::get('users', [Admin\UserController::class, 'index']);
            Route::get('users/{user}', [Admin\UserController::class, 'show']);
            Route::match(['put', 'patch'], 'users/{user}', [Admin\UserController::class, 'update']);

            Route::get('payments', [Admin\FinanceController::class, 'payments']);
            Route::get('payouts', [Admin\FinanceController::class, 'payouts']);
            Route::post('payouts', [Admin\FinanceController::class, 'storePayout']);
            Route::match(['put', 'patch'], 'payouts/{payout}', [Admin\FinanceController::class, 'updatePayout']);

            Route::get('settings', [Admin\FinanceController::class, 'settings']);
            Route::match(['put', 'patch'], 'settings', [Admin\FinanceController::class, 'updateSettings']);
        });

        // ---- Company studio (own company only) ----
        Route::prefix('studio')->middleware('role:company')->group(function () {
            Route::get('dashboard', [Studio\StudioController::class, 'dashboard']);

            Route::get('dramas', [Studio\DramaController::class, 'index']);
            Route::post('dramas', [Studio\DramaController::class, 'store']);
            Route::get('dramas/{drama}', [Studio\DramaController::class, 'show'])->whereNumber('drama');
            Route::match(['put', 'patch'], 'dramas/{drama}', [Studio\DramaController::class, 'update'])->whereNumber('drama');
            Route::delete('dramas/{drama}', [Studio\DramaController::class, 'destroy'])->whereNumber('drama');
            Route::get('dramas/{drama}/episodes', [Studio\DramaController::class, 'episodes'])->whereNumber('drama');
            Route::post('dramas/{drama}/episodes', [Studio\DramaController::class, 'storeEpisode'])->whereNumber('drama');
            Route::get('dramas/{drama}/episodes/{episode}', [Studio\DramaController::class, 'showEpisode'])->whereNumber(['drama', 'episode']);
            Route::match(['put', 'patch'], 'dramas/{drama}/episodes/{episode}', [Studio\DramaController::class, 'updateEpisode'])->whereNumber(['drama', 'episode']);
            Route::delete('dramas/{drama}/episodes/{episode}', [Studio\DramaController::class, 'destroyEpisode'])->whereNumber(['drama', 'episode']);

            Route::get('earnings', [Studio\StudioController::class, 'earnings']);
            Route::get('payouts', [Studio\StudioController::class, 'payouts']);
            Route::get('profile', [Studio\StudioController::class, 'profile']);
            Route::match(['put', 'patch'], 'profile', [Studio\StudioController::class, 'updateProfile']);
        });
    });
});
