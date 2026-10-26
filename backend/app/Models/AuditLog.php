<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Record of an important staff action (publishing, prices, refunds, roles...). */
class AuditLog extends Model
{
    protected $fillable = ['user_id', 'action', 'subject_type', 'subject_id', 'summary', 'changes', 'ip'];

    protected function casts(): array
    {
        return ['changes' => 'array'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @param  array<string,mixed>|null  $changes
     */
    public static function record(string $action, ?Model $subject = null, ?array $changes = null, ?string $summary = null): self
    {
        $request = request();

        return static::create([
            'user_id' => $request->user()?->id,
            'action' => $action,
            'subject_type' => $subject ? class_basename($subject) : null,
            'subject_id' => $subject?->getKey(),
            'summary' => $summary !== null ? mb_substr($summary, 0, 250) : null,
            'changes' => $changes,
            'ip' => $request->ip(),
        ]);
    }

    /**
     * Old/new values of the attributes that changed on a model that was just saved.
     *
     * @param  list<string>|null  $only
     * @return array<string,array{from:mixed,to:mixed}>
     */
    public static function diff(Model $model, ?array $only = null): array
    {
        $diff = [];
        foreach ($model->getChanges() as $key => $to) {
            if (in_array($key, ['updated_at', 'created_at', 'password', 'remember_token', 'config'], true)) {
                continue;
            }
            if ($only !== null && ! in_array($key, $only, true)) {
                continue;
            }
            $diff[$key] = ['from' => $model->getOriginal($key), 'to' => $to];
        }

        return $diff;
    }
}
