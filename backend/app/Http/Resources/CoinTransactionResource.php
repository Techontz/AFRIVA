<?php

namespace App\Http\Resources;

use App\Models\CoinTransaction;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin CoinTransaction */
class CoinTransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'amount' => (int) $this->amount,
            'balance_after' => (int) $this->balance_after,
            'type' => $this->type,
            'description' => $this->description,
            'payment_id' => $this->payment_id,
            'episode' => $this->whenLoaded('episode', fn () => $this->episode ? [
                'id' => $this->episode->id, 'number' => $this->episode->number,
                'drama' => $this->episode->drama ? ['id' => $this->episode->drama->id, 'title' => $this->episode->drama->title, 'slug' => $this->episode->drama->slug] : null,
            ] : null),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
