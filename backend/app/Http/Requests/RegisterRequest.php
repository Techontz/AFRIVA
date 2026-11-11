<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'email' => ['nullable', 'required_without:phone', 'email', 'max:190', 'unique:users,email'],
            'phone' => ['nullable', 'required_without:email', 'string', 'max:32', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:6', 'max:190'],
        ];
    }
}
