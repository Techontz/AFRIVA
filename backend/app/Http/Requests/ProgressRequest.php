<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ProgressRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'progress_seconds' => ['required', 'integer', 'min:0', 'max:86400'],
        ];
    }
}
