<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PaymentMethod extends Model
{
    protected $fillable = [
        'code', 'name', 'type', 'logo_url', 'color', 'is_enabled', 'is_integrated', 'sort_order', 'config',
    ];

    protected $hidden = ['config'];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
            'is_integrated' => 'boolean',
            'sort_order' => 'integer',
            'config' => 'encrypted:array',
        ];
    }
}
