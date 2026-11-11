<?php

namespace App\Http\Resources;

use App\Models\SavedPaymentMethod;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin SavedPaymentMethod */
class SavedPaymentMethodResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'method_code' => $this->method_code,
            'network' => $this->method?->name,
            'phone' => $this->phone,
            'card_brand' => $this->type === 'card' ? $this->method_code : null,
            'card_last4' => $this->card_last4,
            'card_exp_month' => $this->card_exp_month,
            'card_exp_year' => $this->card_exp_year,
            'is_default' => (bool) $this->is_default,
            'is_expired' => $this->isExpired(),
            // A card can be charged again with one tap only when the gateway gave us a token for it.
            'one_tap' => $this->type === 'mobile_money' || ! empty($this->provider_token) || (bool) config('payments.sandbox.auto_approve'),
            'last_used_at' => $this->last_used_at?->toIso8601String(),
        ];
    }
}
