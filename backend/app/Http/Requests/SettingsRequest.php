<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SettingsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'settings' => ['sometimes', 'array'],
            'platform_name' => ['sometimes', 'string', 'max:100'],
            'support_email' => ['sometimes', 'email'],
            'default_currency' => ['sometimes', 'string', 'size:3'],
            'coin_value_tzs' => ['sometimes', 'numeric', 'min:0'],
        ];
    }
}
