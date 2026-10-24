<?php

use App\Exceptions\ApiException;
use App\Http\Middleware\EnsureRole;
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
                return response()->json(['message' => 'Unauthenticated.', 'code' => 'unauthenticated'], 401);
            }
            if ($e instanceof AuthorizationException) {
                return response()->json(['message' => $e->getMessage() ?: 'Forbidden.', 'code' => 'forbidden'], 403);
            }
            if ($e instanceof ModelNotFoundException || $e instanceof NotFoundHttpException) {
                return response()->json(['message' => 'Resource not found.', 'code' => 'not_found'], 404);
            }
            if ($e instanceof HttpExceptionInterface) {
                $status = $e->getStatusCode();
                $codes = [400 => 'bad_request', 401 => 'unauthenticated', 403 => 'forbidden', 405 => 'method_not_allowed',
                    409 => 'conflict', 419 => 'csrf_mismatch', 429 => 'too_many_requests', 503 => 'service_unavailable'];

                return response()->json([
                    'message' => $e->getMessage() ?: 'HTTP error.',
                    'code' => $codes[$status] ?? 'http_error',
                ], $status, $e->getHeaders());
            }

            return response()->json([
                'message' => config('app.debug') ? $e->getMessage() : 'Server error.',
                'code' => 'server_error',
            ], 500);
        });
    })->create();
