<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class DramaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Studio requests are always scoped to the user's own company, so company_id is dropped there.
            'company_id' => $this->is('api/v1/admin/*')
                ? [$this->isAdminCreate() ? 'required' : 'sometimes', 'integer', 'exists:companies,id']
                : ['exclude'],
            'title' => [$this->isMethod('post') ? 'required' : 'sometimes', 'string', 'max:190'],
            'slug' => ['nullable', 'string', 'max:190', 'alpha_dash'],
            'synopsis' => ['nullable', 'string', 'max:10000'],
            'poster_url' => ['nullable', 'string', 'max:500'],
            'backdrop_url' => ['nullable', 'string', 'max:500'],
            'poster' => ['nullable', 'image', 'max:8192'],
            'backdrop' => ['nullable', 'image', 'max:8192'],
            'free_episodes' => ['sometimes', 'integer', 'min:0', 'max:1000'],
            'coins_per_episode' => ['sometimes', 'integer', 'min:0', 'max:100000'],
            'status' => ['sometimes', Rule::in(['draft', 'published'])],
            'is_featured' => ['sometimes', 'boolean'],
            'badge' => ['nullable', Rule::in(['hot', 'new', 'vip'])],
            'language' => ['nullable', 'string', 'max:20'],
            'release_date' => ['nullable', 'date'],
            'category_ids' => ['sometimes', 'array'],
            'category_ids.*' => ['integer', 'exists:categories,id'],
            'tags' => ['sometimes', 'array'],
            'tags.*' => ['string', 'max:60'],
        ];
    }

    protected function isAdminCreate(): bool
    {
        return $this->isMethod('post') && $this->is('api/v1/admin/*');
    }

    protected function prepareForValidation(): void
    {
        // Allow multipart clients to send tags/category_ids as comma-separated strings.
        foreach (['tags', 'category_ids'] as $key) {
            if (is_string($this->input($key))) {
                $this->merge([$key => array_values(array_filter(array_map('trim', explode(',', $this->input($key))), 'strlen'))]);
            }
        }
    }
}
