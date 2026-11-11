<?php

use App\Exceptions\ApiException;
use App\Http\Middleware\EnsureRole;
use App\Http\Middleware\SetLocaleFromHeader;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => EnsureRole::class,
        ]);
        // Locale first so that every API message (including 429s from the throttle) is localized.
        $middleware->api(prepend: [SetLocaleFromHeader::class]);
        $middleware->throttleApi();
        // API is token based: never redirect unauthenticated API calls to a login page.
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('api/*') ? null : '/');
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Uniform error shape for the API: { message, code, errors? }
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! ($request->is('api/*') || $request->expectsJson())) {
                return null;
            }

            // Unmatched routes never reach the api middleware group, so pick the locale here too.
            SetLocaleFromHeader::apply($request);

            if ($e instanceof ApiException) {
                return $e->render();
            }
            if ($e instanceof ValidationException) {
                return response()->json([
                    'message' => $e->getMessage(),
                    'code' => 'validation_error',
                    'errors' => $e->errors(),
                ], $e->status);
            }
            if ($e instanceof AuthenticationException) {
                return response()->json(['message' => __('api.unauthenticated'), 'code' => 'unauthenticated'], 401);
            }
            if ($e instanceof AuthorizationException) {
                return response()->json(['message' => __('api.forbidden'), 'code' => 'forbidden'], 403);
            }
            if ($e instanceof ModelNotFoundException || $e instanceof NotFoundHttpException) {
                return response()->json(['message' => __('api.not_found'), 'code' => 'not_found'], 404);
            }
            if ($e instanceof HttpExceptionInterface) {
                $status = $e->getStatusCode();
                $codes = [400 => 'bad_request', 401 => 'unauthenticated', 403 => 'forbidden', 405 => 'method_not_allowed',
                    409 => 'conflict', 419 => 'csrf_mismatch', 429 => 'too_many_requests', 503 => 'service_unavailable'];

                // Framework messages for these statuses are English only; app aborts pass translated text.
                $generic = [401 => 'api.unauthenticated', 403 => 'api.forbidden', 405 => 'api.method_not_allowed',
                    419 => 'api.csrf_mismatch', 429 => 'api.too_many_requests', 503 => 'api.service_unavailable'];
                $message = in_array($status, [405, 419, 429, 503], true) ? null : $e->getMessage();

                return response()->json([
                    'message' => $message ?: __($generic[$status] ?? 'api.http_error'),
                    'code' => $codes[$status] ?? 'http_error',
                ], $status, $e->getHeaders());
            }

            return response()->json([
                'message' => config('app.debug') ? $e->getMessage() : __('api.server_error'),
                'code' => 'server_error',
            ], 500);
        });
    })->create();
