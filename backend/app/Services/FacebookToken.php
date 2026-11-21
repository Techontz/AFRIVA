<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Verifies a Facebook Login user access token and returns the profile, or null when it is not valid for us.
 * The token must be valid and issued to our own Facebook app (checked with debug_token and the app secret).
 */
class FacebookToken
{
    public const GRAPH = 'https://graph.facebook.com/v21.0';

    public static function configured(): bool
    {
        return filled(config('services.facebook.app_id')) && filled(config('services.facebook.app_secret'));
    }

    /** @return array{id:string,name:?string,email:?string,picture:?string}|null */
    public function verify(string $accessToken): ?array
    {
        if (! self::configured()) {
            return null;
        }
        $appId = (string) config('services.facebook.app_id');
        $appToken = $appId.'|'.config('services.facebook.app_secret');

        try {
            $debug = Http::timeout(10)->connectTimeout(5)->acceptJson()
                ->get(self::GRAPH.'/debug_token', ['input_token' => $accessToken, 'access_token' => $appToken]);
            $info = (array) $debug->json('data', []);
            if (! $debug->successful() || ($info['is_valid'] ?? false) !== true
                || (string) ($info['app_id'] ?? '') !== $appId || empty($info['user_id'])) {
                return null;
            }

            $me = Http::timeout(10)->connectTimeout(5)->acceptJson()
                ->get(self::GRAPH.'/me', [
                    'fields' => 'id,name,email,picture.type(large)',
                    'access_token' => $accessToken,
                    'appsecret_proof' => hash_hmac('sha256', $accessToken, (string) config('services.facebook.app_secret')),
                ]);
        } catch (Throwable) {
            return null;
        }
        $profile = (array) $me->json();
        if (! $me->successful() || (string) ($profile['id'] ?? '') !== (string) $info['user_id']) {
            return null;
        }

        return [
            'id' => (string) $profile['id'],
            'name' => $profile['name'] ?? null,
            // Facebook only returns confirmed emails; it can be missing (phone-only Facebook accounts).
            'email' => isset($profile['email']) ? strtolower((string) $profile['email']) : null,
            'picture' => data_get($profile, 'picture.data.url'),
        ];
    }
}
