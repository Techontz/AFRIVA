<?php

namespace App\Http\Resources;

use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Payment */
class PaymentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'status' => $this->status,
            'amount' => (int) $this->amount,
            'currency' => $this->currency,
            'payment_method' => $this->payment_method_code,
            'payment_method_code' => $this->payment_method_code,
            'phone' => $this->phone,
            'provider_reference' => $this->provider_reference,
            'receipt_number' => $this->receipt_number,
            'fee_amount' => (int) $this->fee_amount,
            'refunded_amount' => (int) $this->refunded_amount,
            'refunded_at' => $this->refunded_at?->toIso8601String(),
            'plan' => $this->whenLoaded('plan', fn () => $this->plan ? new PlanResource($this->plan) : null),
            'user' => $this->whenLoaded('user', fn () => $this->user ? [
                'id' => $this->user->id, 'name' => $this->user->name,
                'email' => $this->user->email, 'phone' => $this->user->phone,
            ] : null),
            'paid_at' => $this->paid_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
