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
            // New clients send `channel` (+ phone or card, or a saved method); older app builds send `payment_method`.
            'channel' => ['nullable', 'string', Rule::in(['mobile_money', 'card'])],
            'payment_method' => ['nullable', 'required_without_all:channel,saved_method_id', 'string', Rule::exists('payment_methods', 'code')->where('is_enabled', true)],
            'saved_method_id' => ['nullable', 'integer'],
            'save' => ['sometimes', 'boolean'],
            'phone' => ['nullable', 'string', 'max:32'],
            'card' => ['nullable', 'array'],
            'card.brand' => ['required_with:card', 'string', Rule::in(['visa', 'mastercard'])],
            'card.last4' => ['required_with:card', 'digits:4'],
            'card.exp_month' => ['required_with:card', 'integer', 'between:1,12'],
            'card.exp_year' => ['required_with:card', 'integer', 'between:2000,2099'],
            // Token from the card gateway's secure fields, once a card provider is connected.
            'card.token' => ['nullable', 'string', 'max:512'],
            // Full card details must never be sent to this API.
            'card.number' => ['prohibited'],
            'card.pan' => ['prohibited'],
            'card.cvc' => ['prohibited'],
            'card.cvv' => ['prohibited'],
        ];
    }
}
