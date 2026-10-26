<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PaymentMethod extends Model
{
    protected $fillable = [
        'code', 'name', 'type', 'logo_url', 'color', 'is_enabled', 'is_integrated', 'sort_order', 'config',
        'fee_percent', 'tested_at',
    ];

    protected $hidden = ['config'];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
            'is_integrated' => 'boolean',
            'sort_order' => 'integer',
            'config' => 'encrypted:array',
            'fee_percent' => 'float',
            'tested_at' => 'datetime',
        ];
    }

    /**
     * Checkout may only use a method that is connected to a tested provider, or any method while the demo sandbox is on.
     * Scope §07: never present a provider as connected before it has been tested.
     */
    public function isAvailable(): bool
    {
        return $this->is_enabled && ($this->is_integrated || (bool) config('payments.sandbox.auto_approve'));
    }
}
