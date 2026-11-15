<?php

namespace App\Models;

use App\Support\MediaStorage;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class StudioApplication extends Model
{
    public const ID_TYPES = ['nida', 'passport'];

    public const STATUSES = ['pending', 'approved', 'rejected'];

    /** Sample videos required before an application can be approved. */
    public const REQUIRED_SAMPLES = 10;

    /** Default private disk for ID documents (never the public disk). PRIVATE_DOCUMENTS_DISK can move them to R2. */
    public const DISK = 'local';

    /** The private disk ID documents live on (config filesystems.private_documents_disk). */
    public static function disk(): string
    {
        return MediaStorage::privateDiskName();
    }

    protected $fillable = [
        'company_id', 'user_id', 'existing_user', 'full_name', 'id_type', 'id_number', 'id_document_path', 'phone',
        'guidelines_accepted_at', 'creator_share_percent', 'status', 'rejection_reason', 'reviewed_at', 'reviewed_by',
    ];

    protected $hidden = ['id_number', 'id_document_path'];

    protected function casts(): array
    {
        return [
            'existing_user' => 'boolean',
            'id_number' => 'encrypted',
            'guidelines_accepted_at' => 'datetime',
            'reviewed_at' => 'datetime',
            'creator_share_percent' => 'float',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function samples(): HasMany
    {
        return $this->hasMany(ApplicationSample::class)->orderBy('id');
    }

    public function validSamplesCount(): int
    {
        return $this->samples->filter(fn (ApplicationSample $s) => $s->isValid())->count();
    }

    /** All required samples are uploaded, processed and the right length. */
    public function readyForReview(): bool
    {
        return $this->validSamplesCount() >= self::REQUIRED_SAMPLES;
    }

    /** pending | ready_for_review | approved | rejected */
    public function reviewStatus(): string
    {
        if ($this->status === 'pending' && $this->readyForReview()) {
            return 'ready_for_review';
        }

        return $this->status;
    }

    /** @return array<string,mixed> Progress summary shared by the applicant and admin views. */
    public function samplesSummary(): array
    {
        return [
            'required' => self::REQUIRED_SAMPLES,
            'uploaded' => $this->samples->count(),
            'valid' => $this->validSamplesCount(),
            'min_seconds' => ApplicationSample::MIN_SECONDS,
            'max_seconds' => ApplicationSample::MAX_SECONDS,
            'max_bytes' => ApplicationSample::MAX_BYTES,
        ];
    }
}
