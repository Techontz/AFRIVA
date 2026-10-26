<?php

namespace App\Http\Requests;

use App\Models\Drama;
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
            'trailer_url' => ['nullable', 'string', 'max:1000'],
            'trailer' => ['nullable', 'file', 'mimetypes:video/mp4,video/quicktime,video/webm,video/x-matroska', 'max:204800'],
            'age_rating' => ['nullable', Rule::in(Drama::AGE_RATINGS)],
            'language' => ['nullable', 'string', 'max:20'],
            // Publishing rules: staff only. Creators propose content; AFRIVA sets dates, prices and free episodes.
            'free_episodes' => $this->staffOnly(['sometimes', 'integer', 'min:0', 'max:1000']),
            'coins_per_episode' => $this->staffOnly(['sometimes', 'integer', 'min:0', 'max:100000']),
            'access_mode' => $this->staffOnly(['sometimes', Rule::in(Drama::ACCESS_MODES)]),
            'status' => $this->staffOnly(['sometimes', Rule::in(['draft', 'published'])]),
            'publish_at' => $this->staffOnly(['nullable', 'date']),
            'is_featured' => $this->staffOnly(['sometimes', 'boolean']),
            'badge' => $this->staffOnly(['nullable', Rule::in(['hot', 'new', 'vip'])]),
            'release_date' => $this->staffOnly(['nullable', 'date']),
            'category_ids' => ['sometimes', 'array'],
            'category_ids.*' => ['integer', 'exists:categories,id'],
            'tags' => ['sometimes', 'array'],
            'tags.*' => ['string', 'max:60'],
        ];
    }

    /** @param list<mixed> $rules */
    protected function staffOnly(array $rules): array
    {
        return $this->is('api/v1/admin/*') ? $rules : ['exclude'];
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
