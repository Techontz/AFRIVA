<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One of the 10 sample videos a creator uploads with a "Request to post" (Bunny Stream, direct TUS upload). */
class ApplicationSample extends Model
{
    /** Accepted length: about 2 minutes (1 to 3 minutes). */
    public const MIN_SECONDS = 60;

    public const MAX_SECONDS = 180;

    /** Client side file size limit (the file goes straight to Bunny, never through this server). */
    public const MAX_BYTES = 500 * 1024 * 1024;

    protected $fillable = ['studio_application_id', 'bunny_video_id', 'title', 'duration_seconds', 'status'];

    protected function casts(): array
    {
        return ['duration_seconds' => 'integer'];
    }

    public function application(): BelongsTo
    {
        return $this->belongsTo(StudioApplication::class, 'studio_application_id');
    }

    /** ok | too_short | too_long | null (not ready yet) */
    public function lengthCheck(): ?string
    {
        if ($this->status !== 'ready' || ! $this->duration_seconds) {
            return null;
        }
        if ($this->duration_seconds < self::MIN_SECONDS) {
            return 'too_short';
        }

        return $this->duration_seconds > self::MAX_SECONDS ? 'too_long' : 'ok';
    }

    public function isValid(): bool
    {
        return $this->lengthCheck() === 'ok';
    }

    /** @return array<string,mixed> */
    public function toPublicArray(): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'status' => $this->status,
            'duration_seconds' => $this->duration_seconds,
            'length_check' => $this->lengthCheck(),
            'valid' => $this->isValid(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
