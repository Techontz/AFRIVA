<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class EpisodeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'number' => [$this->isMethod('post') ? 'nullable' : 'sometimes', 'integer', 'min:1'],
            'title' => ['nullable', 'string', 'max:190'],
            'video_url' => ['nullable', 'string', 'max:1000'],
            'video' => ['nullable', 'file', 'mimetypes:video/mp4,video/quicktime,video/webm,video/x-matroska', 'max:512000'],
            'thumbnail_url' => ['nullable', 'string', 'max:1000'],
            'thumbnail' => ['nullable', 'image', 'max:8192'],
            'duration_seconds' => ['sometimes', 'integer', 'min:0'],
            'subtitle_url' => ['nullable', 'string', 'max:1000'],
            'subtitle' => ['nullable', 'file', 'extensions:vtt,srt', 'max:2048'],
            // Free/locked overrides are a publishing rule (staff only).
            'is_free' => $this->is('api/v1/admin/*') ? ['nullable', 'boolean'] : ['exclude'],
        ];
    }
}
