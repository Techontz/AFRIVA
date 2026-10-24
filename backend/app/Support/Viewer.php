<?php

namespace App\Support;

use App\Models\User;

/**
 * Per-request access to the (optionally) authenticated viewer and cached lookups.
 * Caches live on the Request object so they never leak between requests.
 */
class Viewer
{
    public static function user(): ?User
    {
        return static::remember('viewer.user', function () {
            $user = auth('sanctum')->user();

            return $user instanceof User ? $user : null;
        });
    }

    /** @return array<int,bool> drama_id => true */
    public static function favoriteIds(): array
    {
        return static::remember('viewer.favorites', function () {
            $user = static::user();
            if (! $user) {
                return [];
            }

            return array_fill_keys($user->favorites()->pluck('dramas.id')->all(), true);
        });
    }

    public static function forget(string $key): void
    {
        request()->attributes->remove($key);
    }

    public static function remember(string $key, callable $resolver): mixed
    {
        $attrs = request()->attributes;
        if (! $attrs->has($key)) {
            $attrs->set($key, $resolver());
        }

        return $attrs->get($key);
    }
}
