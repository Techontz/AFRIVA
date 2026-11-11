<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePayoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'amount' => ['sometimes', 'integer', 'min:1'],
            'status' => ['sometimes', Rule::in(['pending', 'paid'])],
            'reference' => ['nullable', 'string', 'max:190'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
