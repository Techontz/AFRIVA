<?php

namespace App\Http\Resources;

use App\Models\PaymentMethod;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin PaymentMethod */
class PaymentMethodResource extends JsonResource
{
    protected bool $withConfig = false;

    public function withConfig(bool $flag = true): static
    {
        $this->withConfig = $flag;

        return $this;
    }

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'name' => $this->name,
            'type' => $this->type,
            'logo_url' => $this->logo_url,
            'color' => $this->color,
            'is_enabled' => (bool) $this->is_enabled,
            'is_integrated' => (bool) $this->is_integrated,
            // Checkout only offers available methods; others are shown as "Inakuja hivi karibuni" (scope §07).
            'is_available' => $this->resource->isAvailable(),
            'fee_percent' => $this->when($this->withConfig, fn () => (float) $this->fee_percent),
            'tested_at' => $this->when($this->withConfig, fn () => $this->tested_at?->toIso8601String()),
            'sort_order' => (int) $this->sort_order,
            'config' => $this->when($this->withConfig, fn () => $this->config ?? (object) []),
        ];
    }
}
