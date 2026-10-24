<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => [$this->isMethod('post') ? 'required' : 'sometimes', 'string', 'max:100'],
            'slug' => ['nullable', 'string', 'max:100', 'alpha_dash', Rule::unique('categories', 'slug')->ignore($this->route('category'))],
            'sort_order' => ['sometimes', 'integer'],
        ];
    }
}
