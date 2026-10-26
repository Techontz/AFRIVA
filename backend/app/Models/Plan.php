<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Plan extends Model
{
    public const TIME_TYPES = ['weekly', 'monthly', 'yearly'];

    public const TYPES = ['weekly', 'monthly', 'yearly', 'episodes', 'coins'];

    protected $fillable = [
        'name', 'type', 'price', 'currency', 'duration_days', 'episode_quota', 'coins', 'bonus_coins',
        'description', 'features', 'is_popular', 'is_active', 'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'integer',
            'duration_days' => 'integer',
            'episode_quota' => 'integer',
            'coins' => 'integer',
            'bonus_coins' => 'integer',
            'features' => 'array',
            'is_popular' => 'boolean',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function isTimeBased(): bool
    {
        return in_array($this->type, self::TIME_TYPES, true);
    }
}
