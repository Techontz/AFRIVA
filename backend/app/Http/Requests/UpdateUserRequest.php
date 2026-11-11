<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:120'],
            'status' => ['sometimes', Rule::in(['active', 'suspended'])],
            'role' => ['sometimes', Rule::in(['viewer', 'company', 'super_admin'])],
            'company_id' => ['nullable', 'integer', 'exists:companies,id'],
            'coins' => ['sometimes', 'integer', 'min:0'],
            'coins_adjust' => ['sometimes', 'integer'],
            'password' => ['sometimes', 'string', 'min:6'],
        ];
    }
}
