<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCompanyRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:150'],
            'slug' => ['sometimes', 'string', 'max:150', 'alpha_dash', Rule::unique('companies', 'slug')->ignore($this->route('company'))],
            'email' => ['nullable', 'email', 'max:190'],
            'phone' => ['nullable', 'string', 'max:32'],
            'country' => ['nullable', 'string', 'size:2'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'logo' => ['nullable', 'image', 'max:4096'],
            'revenue_share_percent' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'status' => ['sometimes', Rule::in(['active', 'suspended'])],
            'description' => ['nullable', 'string', 'max:5000'],
            'owner_password' => ['nullable', 'string', 'min:6', 'max:190'],
        ];
    }
}
