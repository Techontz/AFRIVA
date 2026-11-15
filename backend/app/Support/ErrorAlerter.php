<?php

namespace App\Support;

use App\Exceptions\ApiException;
use App\Mail\ErrorAlert;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Throwable;

/**
 * Free error monitoring: emails INFRA_ALERT_EMAIL a short summary of a reported exception, at most once per
 * exception class per INFRA_ERROR_ALERT_THROTTLE_MINUTES (default 10). Off unless INFRA_ALERT_EMAIL is set and a
 * real mailer is configured (not "log" or "array"). Never throws: a broken mailer must not break the request.
 */
class ErrorAlerter
{
    protected static bool $sending = false;

    public static function enabled(): bool
    {
        return (bool) config('infra.error_alerts', true)
            && filter_var(config('infra.alert_email'), FILTER_VALIDATE_EMAIL)
            && ! in_array(config('mail.default'), ['log', 'array', null], true);
    }

    public static function report(Throwable $e): void
    {
        if (self::$sending || $e instanceof ApiException || ! self::enabled()) {
            return;
        }
        self::$sending = true;
        try {
            $minutes = max(1, (int) config('infra.error_alert_throttle_minutes', 10));
            if (! Cache::add('infra:error-alert:'.md5($e::class), 1, $minutes * 60)) {
                return; // already emailed for this class within the window
            }
            $request = app()->runningInConsole() ? null : request();
            Mail::to((string) config('infra.alert_email'))->send(new ErrorAlert($e::class, [
                'class' => $e::class,
                'message' => Str::limit($e->getMessage(), 300),
                'location' => str_replace(base_path().'/', '', $e->getFile()).':'.$e->getLine(),
                'request' => $request ? $request->method().' '.$request->path() : 'console',
                'environment' => app()->environment(),
                'version' => config('app.version') ?: config('app.commit'),
                'time' => now()->toIso8601String(),
            ]));
        } catch (Throwable) {
            // swallow: alerting must never cause another error
        } finally {
            self::$sending = false;
        }
    }
}
