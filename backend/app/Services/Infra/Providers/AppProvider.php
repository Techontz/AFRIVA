<?php

namespace App\Services\Infra\Providers;

use App\Models\ApplicationSample;
use App\Models\Episode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Video pipeline health from this app's own database: episodes with videos, processing and failed uploads. */
class AppProvider extends Provider
{
    public function key(): string
    {
        return 'app';
    }

    public function source(): string
    {
        return 'Afriva database';
    }

    public function collect(): array
    {
        $byStatus = Episode::query()->select('video_status', DB::raw('COUNT(*) as c'))->groupBy('video_status')
            ->pluck('c', 'video_status')->map(fn ($c) => (int) $c)->all();
        $stuckBefore = now()->subHours(2);
        $samples = ApplicationSample::query()->select('status', DB::raw('COUNT(*) as c'))->groupBy('status')
            ->pluck('c', 'status')->map(fn ($c) => (int) $c)->all();

        return [
            'episodes_total' => array_sum($byStatus),
            'episodes_with_video' => Episode::where(fn ($q) => $q->whereNotNull('bunny_video_id')
                ->orWhere(fn ($q) => $q->whereNotNull('video_url')->where('video_url', '!=', '')))->count(),
            'episodes_on_bunny' => Episode::whereNotNull('bunny_video_id')->count(),
            'episodes_by_status' => $byStatus,
            'episodes_processing' => ($byStatus['uploading'] ?? 0) + ($byStatus['processing'] ?? 0),
            'episodes_failed' => $byStatus['failed'] ?? 0,
            'episodes_stuck' => Episode::whereIn('video_status', ['uploading', 'processing'])->where('updated_at', '<', $stuckBefore)->count(),
            'samples_by_status' => $samples,
            'samples_failed' => $samples['failed'] ?? 0,
            'samples_processing' => ($samples['uploading'] ?? 0) + ($samples['processing'] ?? 0),
            'failed_jobs' => Schema::hasTable('failed_jobs') ? DB::table('failed_jobs')->count() : null,
        ];
    }
}
