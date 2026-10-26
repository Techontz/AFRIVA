<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdatePaymentMethodRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:100'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'color' => ['nullable', 'string', 'max:20'],
            'is_enabled' => ['sometimes', 'boolean'],
            // Only switch on after a successful live test with the provider (scope §07).
            'is_integrated' => ['sometimes', 'boolean'],
            'fee_percent' => ['sometimes', 'numeric', 'min:0', 'max:50'],
            'sort_order' => ['sometimes', 'integer'],
            'config' => ['nullable', 'array'],
        ];
    }
}
