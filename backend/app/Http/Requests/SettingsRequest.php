<?php

namespace App\Http\Requests;

use App\Models\Setting;
use Illuminate\Foundation\Http\FormRequest;

class SettingsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $links = [];
        foreach (Setting::SOCIAL_KEYS as $key) {
            $links[$key] = $links["settings.$key"] = ['sometimes', 'nullable', 'url:http,https', 'max:255'];
        }

        return $links + [
            'settings' => ['sometimes', 'array'],
            'platform_name' => ['sometimes', 'string', 'max:100'],
            'support_email' => ['sometimes', 'email'],
            'default_currency' => ['sometimes', 'string', 'size:3'],
            'coin_value_tzs' => ['sometimes', 'numeric', 'min:0'],
            'creator_revenue_share_percent' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'settings.creator_revenue_share_percent' => ['sometimes', 'numeric', 'min:0', 'max:100'],
        ];
    }
}
