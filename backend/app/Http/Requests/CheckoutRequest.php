<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CheckoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plan_id' => ['required', 'integer', Rule::exists('plans', 'id')->where('is_active', true)],
            'payment_method' => ['required', 'string', Rule::exists('payment_methods', 'code')->where('is_enabled', true)],
            'phone' => ['nullable', 'string', 'max:32'],
            'card' => ['nullable', 'array'],
        ];
    }
}
