<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\PaymentMethod */
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
            'sort_order' => (int) $this->sort_order,
            'config' => $this->when($this->withConfig, fn () => $this->config ?? (object) []),
        ];
    }
}
