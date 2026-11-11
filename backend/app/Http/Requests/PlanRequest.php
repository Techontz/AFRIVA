<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PlanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => [$this->isMethod('post') ? 'required' : 'sometimes', 'string', 'max:120'],
            'type' => [$this->isMethod('post') ? 'required' : 'sometimes', Rule::in(['weekly', 'monthly', 'yearly', 'episodes', 'coins'])],
            'price' => [$this->isMethod('post') ? 'required' : 'sometimes', 'integer', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
            'duration_days' => ['nullable', 'integer', 'min:1'],
            'episode_quota' => ['nullable', 'integer', 'min:1'],
            'coins' => ['nullable', 'integer', 'min:1'],
            'bonus_coins' => ['nullable', 'integer', 'min:0'],
            'description' => ['nullable', 'string', 'max:2000'],
            'features' => ['nullable', 'array'],
            'features.*' => ['string', 'max:200'],
            'is_popular' => ['sometimes', 'boolean'],
            'is_active' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer'],
        ];
    }
}
