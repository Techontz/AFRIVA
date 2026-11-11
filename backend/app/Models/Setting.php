<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    protected $fillable = ['key', 'value'];

    public const DEFAULTS = [
        'platform_name' => 'Afriva',
        'support_email' => 'support@afriva.co.tz',
        'default_currency' => 'TZS',
        'coin_value_tzs' => '10',
        // Share of content revenue paid to creators/studios (Afriva keeps the rest). Shown in the creator guidelines.
        'creator_revenue_share_percent' => '60',
        // Public profile links shown in the website footer; empty ones are hidden.
        'social_facebook' => '',
        'social_youtube' => '',
        'social_tiktok' => '',
        'social_instagram' => '',
    ];

    public const SOCIAL_KEYS = ['social_facebook', 'social_youtube', 'social_tiktok', 'social_instagram'];

    public static function get(string $key, mixed $default = null): mixed
    {
        $value = static::where('key', $key)->value('value');

        return $value ?? ($default ?? (self::DEFAULTS[$key] ?? null));
    }

    public static function put(string $key, mixed $value): void
    {
        static::updateOrCreate(['key' => $key], ['value' => is_scalar($value) || $value === null ? $value : json_encode($value)]);
    }

    /** Creator share 0..100 from the admin setting (default 60). */
    public static function creatorShare(): float
    {
        $v = (float) static::get('creator_revenue_share_percent');

        return round(max(0, min(100, $v)), 2);
    }

    /** @return array{creator_percent: float, platform_percent: float} */
    public static function revenueSplit(): array
    {
        $creator = static::creatorShare();

        return ['creator_percent' => $creator, 'platform_percent' => round(100 - $creator, 2)];
    }

    /** @return array<string,mixed> */
    public static function allAsArray(): array
    {
        return array_merge(self::DEFAULTS, static::pluck('value', 'key')->all());
    }
}
