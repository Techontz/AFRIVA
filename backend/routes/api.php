<?php

use App\Http\Controllers\Api\V1\Admin;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\CreatorController;
use App\Http\Controllers\Api\V1\EpisodeController;
use App\Http\Controllers\Api\V1\EventController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\MediaController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\Studio;
use Illuminate\Support\Facades\Route;

/*
| Afriva REST API v1, see SPEC.md §6. All responses: { data, meta? }; errors: { message, code, errors? }.
*/
Route::prefix('v1')->group(function () {

    // ---- Auth -------------------------------------------------------------
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:20,1');
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:30,1');

    // ---- Public catalogue (auth optional: token, if sent, personalises is_favorite / is_unlocked / continue watching) ----
    Route::get('home', [CatalogController::class, 'home']);
    Route::get('categories', [CatalogController::class, 'categories']);
    Route::get('dramas', [CatalogController::class, 'dramas']);
    Route::get('dramas/rankings', [CatalogController::class, 'rankings']);
    Route::get('dramas/{slug}', [CatalogController::class, 'show']);
    Route::post('dramas/{id}/report', [ReportController::class, 'store'])->whereNumber('id')->middleware('throttle:10,1');
    Route::get('feed', [CatalogController::class, 'feed']);
    Route::get('plans', [CatalogController::class, 'plans']);
    Route::get('payment-methods', [CatalogController::class, 'paymentMethods']);
    Route::get('episodes/{id}/play', [EpisodeController::class, 'play'])->whereNumber('id');
    Route::post('events', [EventController::class, 'store'])->middleware('throttle:240,1');
    Route::get('media/videos/{path}', [MediaController::class, 'video'])
        ->where('path', '.*')->middleware('signed:relative')->name('media.video');

    // ---- Payment provider webhooks (public; the server verifies, never the app) ----
    Route::post('payments/callback/{provider}', [PaymentController::class, 'callback']);

    // ---- Authenticated viewer ----
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('auth/me', [AuthController::class, 'me']);

        Route::post('episodes/{id}/unlock', [EpisodeController::class, 'unlock'])->whereNumber('id');
        Route::post('episodes/{id}/progress', [EpisodeController::class, 'progress'])->whereNumber('id');

        Route::post('checkout', [PaymentController::class, 'checkout'])->middleware('throttle:20,1');
        Route::get('payments/{reference}', [PaymentController::class, 'show']);

        Route::get('me/subscription', [MeController::class, 'subscription']);
        Route::get('me/payments', [MeController::class, 'payments']);
        Route::get('me/payments/{reference}/receipt', [PaymentController::class, 'receipt']);
        Route::get('me/coins', [MeController::class, 'coins']);
        Route::get('me/history', [MeController::class, 'history']);
        Route::get('me/favorites', [MeController::class, 'favorites']);
        Route::post('me/favorites/{drama_id}', [MeController::class, 'toggleFavorite'])->whereNumber('drama_id');

        // "Wasilisha Kazi Yako": a viewer becomes a creator.
        Route::post('creator/apply', [CreatorController::class, 'apply'])->middleware('throttle:5,1');

        // ---- Staff (role super_admin; each area also needs the staff role's permission) ----
        Route::prefix('admin')->middleware('role:super_admin')->group(function () {
            Route::get('dashboard', Admin\DashboardController::class)->middleware('staff:dashboard');

            // Content: series, episodes, categories, video library, publishing
            Route::middleware('staff:content')->group(function () {
                Route::apiResource('categories', Admin\CategoryController::class);

                Route::post('dramas', [Admin\DramaController::class, 'store']);
                Route::match(['put', 'patch'], 'dramas/{drama}', [Admin\DramaController::class, 'update'])->whereNumber('drama');
                Route::delete('dramas/{drama}', [Admin\DramaController::class, 'destroy'])->whereNumber('drama');
                Route::post('dramas/{drama}/episodes', [Admin\DramaController::class, 'storeEpisode'])->whereNumber('drama');
                Route::post('dramas/{drama}/episodes/reorder', [Admin\DramaController::class, 'reorderEpisodes'])->whereNumber('drama');
                Route::match(['put', 'patch'], 'dramas/{drama}/episodes/{episode}', [Admin\DramaController::class, 'updateEpisode'])->whereNumber(['drama', 'episode']);
                Route::delete('dramas/{drama}/episodes/{episode}', [Admin\DramaController::class, 'destroyEpisode'])->whereNumber(['drama', 'episode']);

                Route::get('videos', [Admin\VideoController::class, 'index']);
                Route::post('videos/{episode}/reprocess', [Admin\VideoController::class, 'reprocess'])->whereNumber('episode');
            });
            Route::middleware('staff:content,review,publish')->group(function () {
                Route::get('dramas', [Admin\DramaController::class, 'index']);
                Route::get('dramas/{drama}', [Admin\DramaController::class, 'show'])->whereNumber('drama');
                Route::get('dramas/{drama}/episodes', [Admin\DramaController::class, 'episodes'])->whereNumber('drama');
                Route::get('dramas/{drama}/episodes/{episode}', [Admin\DramaController::class, 'showEpisode'])->whereNumber(['drama', 'episode']);
            });
            Route::middleware('staff:publish')->group(function () {
                Route::post('dramas/{drama}/publish', [Admin\PublishController::class, 'publish'])->whereNumber('drama');
                Route::post('dramas/{drama}/unpublish', [Admin\PublishController::class, 'unpublish'])->whereNumber('drama');
            });

            // Review queue (Kagua)
            Route::middleware('staff:review')->group(function () {
                Route::get('reviews', [Admin\ReviewController::class, 'index']);
                Route::get('reviews/{drama}', [Admin\ReviewController::class, 'show'])->whereNumber('drama');
                Route::post('reviews/{drama}/start', [Admin\ReviewController::class, 'start'])->whereNumber('drama');
                Route::post('reviews/{drama}/decide', [Admin\ReviewController::class, 'decide'])->whereNumber('drama');
                Route::post('episodes/{episode}/verify-playback', [Admin\ReviewController::class, 'verifyPlayback'])->whereNumber('episode');
            });

            Route::middleware('staff:reports')->group(function () {
                Route::get('reports', [Admin\ContentReportController::class, 'index']);
                Route::match(['put', 'patch'], 'reports/{report}', [Admin\ContentReportController::class, 'update'])->whereNumber('report');
            });

            // Creators (companies / individual creators)
            Route::middleware('staff:creators')->group(function () {
                Route::get('companies/{company}/stats', [Admin\CompanyController::class, 'stats']);
                Route::apiResource('companies', Admin\CompanyController::class);
            });

            // Money: plans, payment methods, payments (Miamala), refunds, payouts, costs
            Route::middleware('staff:finance')->group(function () {
                Route::apiResource('plans', Admin\PlanController::class);
                Route::get('payment-methods', [Admin\PaymentMethodController::class, 'index']);
                Route::get('payment-methods/{paymentMethod}', [Admin\PaymentMethodController::class, 'show']);
                Route::match(['put', 'patch'], 'payment-methods/{paymentMethod}', [Admin\PaymentMethodController::class, 'update']);

                Route::get('payments', [Admin\FinanceController::class, 'payments']);
                Route::get('payments/{payment}', [Admin\FinanceController::class, 'showPayment'])->whereNumber('payment');
                Route::post('payments/{payment}/refund', [Admin\FinanceController::class, 'refund'])->whereNumber('payment');
                Route::get('coin-transactions', [Admin\FinanceController::class, 'coinTransactions']);
                Route::get('payouts', [Admin\FinanceController::class, 'payouts']);
                Route::post('payouts', [Admin\FinanceController::class, 'storePayout']);
                Route::match(['put', 'patch'], 'payouts/{payout}', [Admin\FinanceController::class, 'updatePayout']);

                Route::get('costs', [Admin\AnalyticsController::class, 'costs']);
                Route::post('costs', [Admin\AnalyticsController::class, 'storeCost']);
                Route::delete('costs/{cost}', [Admin\AnalyticsController::class, 'destroyCost'])->whereNumber('cost');
            });

            Route::middleware('staff:analytics')->group(function () {
                Route::get('analytics', [Admin\AnalyticsController::class, 'overview']);
                Route::get('analytics/dramas/{drama}', [Admin\AnalyticsController::class, 'drama'])->whereNumber('drama');
            });

            Route::middleware('staff:users')->group(function () {
                Route::get('users', [Admin\UserController::class, 'index']);
                Route::get('users/{user}', [Admin\UserController::class, 'show']);
                Route::match(['put', 'patch'], 'users/{user}', [Admin\UserController::class, 'update']);
            });

            Route::middleware('staff:settings')->group(function () {
                Route::get('settings', [Admin\FinanceController::class, 'settings']);
                Route::match(['put', 'patch'], 'settings', [Admin\FinanceController::class, 'updateSettings']);
            });

            Route::middleware('staff:staff')->group(function () {
                Route::get('staff', [Admin\StaffController::class, 'index']);
                Route::post('staff', [Admin\StaffController::class, 'store']);
                Route::match(['put', 'patch'], 'staff/{user}', [Admin\StaffController::class, 'update']);
            });

            Route::get('audit-logs', [Admin\AuditLogController::class, 'index'])->middleware('staff:audit');
        });

        // ---- Creator Studio (own company only) ----
        Route::prefix('studio')->middleware('role:company')->group(function () {
            Route::get('dashboard', [Studio\StudioController::class, 'dashboard']);
            Route::get('analytics', [Studio\StudioController::class, 'analytics']);
            Route::get('agreement', [Studio\StudioController::class, 'agreement']);
            Route::post('agreement', [Studio\StudioController::class, 'acceptAgreement']);

            Route::get('dramas', [Studio\DramaController::class, 'index']);
            Route::post('dramas', [Studio\DramaController::class, 'store']);
            Route::get('dramas/{drama}', [Studio\DramaController::class, 'show'])->whereNumber('drama');
            Route::match(['put', 'patch'], 'dramas/{drama}', [Studio\DramaController::class, 'update'])->whereNumber('drama');
            Route::delete('dramas/{drama}', [Studio\DramaController::class, 'destroy'])->whereNumber('drama');
            Route::post('dramas/{drama}/submit', [Studio\DramaController::class, 'submit'])->whereNumber('drama');
            Route::get('dramas/{drama}/analytics', [Studio\DramaController::class, 'analytics'])->whereNumber('drama');
            Route::get('dramas/{drama}/episodes', [Studio\DramaController::class, 'episodes'])->whereNumber('drama');
            Route::post('dramas/{drama}/episodes', [Studio\DramaController::class, 'storeEpisode'])->whereNumber('drama');
            Route::post('dramas/{drama}/episodes/reorder', [Studio\DramaController::class, 'reorderEpisodes'])->whereNumber('drama');
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
