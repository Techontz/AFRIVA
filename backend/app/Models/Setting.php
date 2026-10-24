<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    protected $fillable = ['key', 'value'];

    public const DEFAULTS = [
        'platform_name' => 'Afriva',
        'support_email' => 'support@afriva.com',
        'default_currency' => 'TZS',
        'coin_value_tzs' => '10',
    ];

    public static function get(string $key, mixed $default = null): mixed
    {
        $value = static::where('key', $key)->value('value');

        return $value ?? ($default ?? (self::DEFAULTS[$key] ?? null));
    }

    public static function put(string $key, mixed $value): void
    {
        static::updateOrCreate(['key' => $key], ['value' => is_scalar($value) || $value === null ? $value : json_encode($value)]);
    }

    /** @return array<string,mixed> */
    public static function allAsArray(): array
    {
        return array_merge(self::DEFAULTS, static::pluck('value', 'key')->all());
    }
}
