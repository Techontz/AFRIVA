<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Verifies a Google Sign-In ID token with Google and returns its claims, or null when it is not valid for us.
 * Accepted only when it was issued by Google for one of our own client IDs, is unexpired, and the email is verified.
 */
class GoogleIdToken
{
    public const ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];

    /** @return array<string,mixed>|null */
    public function verify(string $idToken): ?array
    {
        $clientIds = config('services.google.client_ids', []);
        if ($clientIds === []) {
            return null;
        }

        try {
            $res = Http::timeout(10)->connectTimeout(5)->acceptJson()
                ->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);
        } catch (Throwable) {
            return null;
        }
        if (! $res->successful()) {
            return null;
        }

        $claims = (array) $res->json();
        $verified = in_array($claims['email_verified'] ?? null, [true, 'true'], true);
        if (! in_array($claims['aud'] ?? null, $clientIds, true)
            || ! in_array($claims['iss'] ?? null, self::ISSUERS, true)
            || (int) ($claims['exp'] ?? 0) < time()
            || empty($claims['sub']) || empty($claims['email']) || ! $verified) {
            return null;
        }

        return $claims;
    }
}
