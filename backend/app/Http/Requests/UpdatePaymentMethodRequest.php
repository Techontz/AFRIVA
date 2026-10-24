<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

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
            'is_integrated' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer'],
            'config' => ['nullable', 'array'],
        ];
    }
}
