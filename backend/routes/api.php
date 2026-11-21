<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\CreatorApplicationController;
use App\Http\Controllers\Api\V1\EpisodeController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\SavedPaymentMethodController;
use App\Http\Controllers\Api\V1\Studio;
use App\Http\Controllers\Api\V1\StudioApplicationController;
use App\Http\Controllers\Api\V1\Webhooks\BunnyWebhookController;
use Illuminate\Support\Facades\Route;

/*
| Afriva REST API v1 — see SPEC.md §6. All responses: { data, meta? }; errors: { message, code, errors? }.
*/
Route::prefix('v1')->group(function () {

    // ---- Health (public, no secrets): 200 when DB, cache, queue and storage pass, else 503. /up stays too. ----
    Route::get('health', HealthController::class)->middleware('throttle:60,1');

    // ---- Auth -------------------------------------------------------------
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:20,1');
        Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:30,1');
    Route::post('auth/google', [AuthController::class, 'google'])->middleware('throttle:30,1');
    Route::post('auth/facebook', [AuthController::class, 'facebook'])->middleware('throttle:30,1');
    // "Request to post": guests or logged-in viewers (bearer token optional).
    Route::post('auth/studio-application', [StudioApplicationController::class, 'store'])->middleware('throttle:5,1');
    Route::get('creator-guidelines', [StudioApplicationController::class, 'guidelines']);

    // ---- Public catalogue (auth optional: token, if sent, personalises is_favorite / is_unlocked) ----
        // Anonymous answers may be cached for 60 s by the CDN and browsers (see PublicCache).
    Route::middleware('public.cache:60')->group(function () {
        Route::get('home', [CatalogController::class, 'home']);
        Route::get('categories', [CatalogController::class, 'categories']);
        Route::get('site-info', [CatalogController::class, 'siteInfo']);
        Route::get('dramas', [CatalogController::class, 'dramas']);
        Route::get('dramas/rankings', [CatalogController::class, 'rankings']);
        Route::get('dramas/{slug}', [CatalogController::class, 'show']);
        Route::get('feed', [CatalogController::class, 'feed']);
        Route::get('plans', [CatalogController::class, 'plans']);
        Route::get('payment-methods', [CatalogController::class, 'paymentMethods']);
        Route::get('checkout/options', [SavedPaymentMethodController::class, 'options']);
    });
    Route::get('episodes/{id}/play', [EpisodeController::class, 'play'])->whereNumber('id');
    Route::post('episodes/{id}/view', [EpisodeController::class, 'view'])->whereNumber('id')->middleware('throttle:120,1');

    // ---- Payment provider webhooks (public) ----
    Route::post('payments/callback/{provider}', [PaymentController::class, 'callback']);

    // ---- Bunny Stream video status webhook (public; verified against Bunny's Get Video) ----
    Route::post('webhooks/bunny', BunnyWebhookController::class)->middleware('throttle:300,1');

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
        Route::get('me/payment-methods', [SavedPaymentMethodController::class, 'index']);
        Route::post('me/payment-methods', [SavedPaymentMethodController::class, 'store'])->middleware('throttle:20,1');
        Route::match(['put', 'patch'], 'me/payment-methods/{id}', [SavedPaymentMethodController::class, 'update'])->whereNumber('id');
        Route::delete('me/payment-methods/{id}', [SavedPaymentMethodController::class, 'destroy'])->whereNumber('id');
        Route::get('me/history', [MeController::class, 'history']);
        Route::get('me/favorites', [MeController::class, 'favorites']);
        // The applicant's own request to post + its 10 sample videos (pending studio logins can reach these).
        Route::get('me/studio-application', [CreatorApplicationController::class, 'show']);
        Route::post('me/studio-application/samples', [CreatorApplicationController::class, 'storeSample'])->middleware('throttle:30,1');
        Route::post('me/studio-application/samples/{sample}/complete', [CreatorApplicationController::class, 'completeSample'])->whereNumber('sample');
        Route::delete('me/studio-application/samples/{sample}', [CreatorApplicationController::class, 'destroySample'])->whereNumber('sample');
        Route::post('me/favorites/{drama_id}', [MeController::class, 'toggleFavorite'])->whereNumber('drama_id');

        // ---- Super admin ----
        Route::prefix('admin')->middleware('role:super_admin')->group(function () {
            Route::get('dashboard', Admin\DashboardController::class);
            Route::get('infrastructure', Admin\InfrastructureController::class)->middleware('throttle:30,1');

            Route::get('companies/{company}/stats', [Admin\CompanyController::class, 'stats']);
            Route::get('companies/{company}/samples', [Admin\CompanyController::class, 'samples']);
            Route::get('companies/{company}/id-document', [Admin\CompanyController::class, 'idDocument'])->middleware('throttle:60,1');
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
            Route::post('dramas/{drama}/episodes/{episode}/video-upload', [Admin\DramaController::class, 'videoUpload'])->whereNumber(['drama', 'episode'])->middleware('throttle:30,1');
            Route::post('dramas/{drama}/episodes/{episode}/video-upload/complete', [Admin\DramaController::class, 'videoUploadComplete'])->whereNumber(['drama', 'episode']);

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
            Route::post('dramas/{drama}/episodes/{episode}/video-upload', [Studio\DramaController::class, 'videoUpload'])->whereNumber(['drama', 'episode'])->middleware('throttle:30,1');
            Route::post('dramas/{drama}/episodes/{episode}/video-upload/complete', [Studio\DramaController::class, 'videoUploadComplete'])->whereNumber(['drama', 'episode']);

            Route::get('earnings', [Studio\StudioController::class, 'earnings']);
            Route::get('payouts', [Studio\StudioController::class, 'payouts']);
            Route::get('profile', [Studio\StudioController::class, 'profile']);
            Route::match(['put', 'patch'], 'profile', [Studio\StudioController::class, 'updateProfile']);
        });
    });
});
