<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Checks Google Play one-time purchases with the Android Publisher API, using a service account
 * (JSON key) that has access to the app in Play Console. No SDK needed: the OAuth token is a signed JWT.
 */
class GooglePlayPurchases
{
    public const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

    public static function configured(): bool
    {
        return filled(config('services.google_play.package')) && self::credentials() !== null;
    }

    /** @return array{client_email:string,private_key:string,token_uri?:string}|null */
    protected static function credentials(): ?array
    {
        $raw = config('services.google_play.service_account');
        if (blank($raw)) {
            return null;
        }
        $json = str_starts_with(trim((string) $raw), '{') ? (string) $raw : (is_file((string) $raw) ? file_get_contents((string) $raw) : null);
        $data = $json ? json_decode($json, true) : null;

        return is_array($data) && ! empty($data['client_email']) && ! empty($data['private_key']) ? $data : null;
    }

    /**
     * The purchase as Google reports it, or null when it is not a completed purchase of this product.
     *
     * @return array{orderId:?string,purchaseState:int,consumptionState:int,acknowledgementState:int}|null
     */
    public function verify(string $productId, string $token): ?array
    {
        $access = $this->accessToken();
        if (! $access) {
            return null;
        }
        $package = (string) config('services.google_play.package');
        try {
            $res = Http::timeout(15)->connectTimeout(5)->withToken($access)->acceptJson()->get(
                'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'
                .rawurlencode($package).'/purchases/products/'.rawurlencode($productId).'/tokens/'.rawurlencode($token)
            );
        } catch (Throwable) {
            return null;
        }
        $p = (array) $res->json();
        // purchaseState: 0 purchased, 1 cancelled, 2 pending.
        if (! $res->successful() || (int) ($p['purchaseState'] ?? -1) !== 0) {
            return null;
        }

        return [
            'orderId' => $p['orderId'] ?? null,
            'purchaseState' => 0,
            'consumptionState' => (int) ($p['consumptionState'] ?? 0),
            'acknowledgementState' => (int) ($p['acknowledgementState'] ?? 0),
        ];
    }

    protected function accessToken(): ?string
    {
        $creds = self::credentials();
        if (! $creds) {
            return null;
        }

        $cached = Cache::get('google_play.access_token');
        if ($cached) {
            return $cached;
        }
        $token = (function () use ($creds) {
            $uri = $creds['token_uri'] ?? 'https://oauth2.googleapis.com/token';
            $now = time();
            $b64 = fn (string $s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
            $head = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = $b64(json_encode(['iss' => $creds['client_email'], 'scope' => self::SCOPE, 'aud' => $uri, 'iat' => $now, 'exp' => $now + 3600]));
            $signature = '';
            if (! openssl_sign("$head.$claims", $signature, $creds['private_key'], OPENSSL_ALGO_SHA256)) {
                return null;
            }
            try {
                $res = Http::asForm()->timeout(15)->post($uri, [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => "$head.$claims.".$b64($signature),
                ]);
            } catch (Throwable) {
                return null;
            }

            return $res->successful() ? $res->json('access_token') : null;
        })();
        if ($token) {
            Cache::put('google_play.access_token', $token, 3000); // Google tokens live one hour.
        }

        return $token ?: null;
    }
}
