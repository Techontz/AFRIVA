<?php

namespace App\Http\Requests;

use App\Models\Company;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StudioProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:150'],
            'email' => ['nullable', 'email', 'max:190'],
            'phone' => ['nullable', 'string', 'max:32'],
            'country' => ['nullable', 'string', 'size:2'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'logo' => ['nullable', 'image', 'max:4096'],
            'description' => ['nullable', 'string', 'max:5000'],
            // Where Afriva sends the studio's share.
            'payout_method' => ['nullable', Rule::in(Company::PAYOUT_METHODS)],
            'payout_provider' => ['nullable', 'required_if:payout_method,mobile_money', Rule::in(Company::PAYOUT_PROVIDERS)],
            'payout_bank_name' => ['nullable', 'required_if:payout_method,bank', 'string', 'max:120'],
            'payout_account_name' => ['nullable', 'required_with:payout_method', 'string', 'max:150'],
            'payout_account_number' => ['nullable', 'required_with:payout_method', 'string', 'max:60', 'regex:/^[A-Za-z0-9\- +]+$/'],
        ];
    }
}
