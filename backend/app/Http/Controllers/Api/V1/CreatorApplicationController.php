<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\ApplicationSample;
use App\Models\Setting;
use App\Models\StudioApplication;
use App\Services\BunnyStream;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The applicant's own "Request to post": review status and the 10 sample videos.
 * Open to the applicant's login while pending (pending studio logins can reach nothing else in Studio).
 * Samples go straight from the client to Bunny Stream over TUS, never through this server.
 */
class CreatorApplicationController extends Controller
{
    protected function application(Request $request): ?StudioApplication
    {
        return StudioApplication::with(['company:id,name,status', 'samples'])
            ->where('user_id', $request->user()->id)->latest('id')->first();
    }

    protected function openApplication(Request $request): StudioApplication
    {
        $app = $this->application($request);
        if (! $app) {
            abort(404);
        }
        if ($app->status !== 'pending') {
            throw new ApiException(__('api.application_closed'), 'application_closed', 409);
        }

        return $app;
    }

    protected function present(StudioApplication $app): array
    {
        return [
            'id' => $app->id,
            'status' => $app->status,
            'review_status' => $app->reviewStatus(),
            'rejection_reason' => $app->status === 'rejected' ? $app->rejection_reason : null,
            'company' => $app->company ? ['id' => $app->company->id, 'name' => $app->company->name, 'status' => $app->company->status] : null,
            'samples' => $app->samples->map->toPublicArray()->values(),
            'samples_summary' => $app->samplesSummary(),
            'revenue_split' => Setting::revenueSplit(),
            'created_at' => $app->created_at?->toIso8601String(),
            'reviewed_at' => $app->reviewed_at?->toIso8601String(),
        ];
    }

    /** GET me/studio-application: latest request, refreshing samples Bunny is still working on. */
    public function show(Request $request, BunnyStream $bunny): JsonResponse
    {
        $app = $this->application($request);
        if (! $app) {
            return $this->ok(null);
        }
        if ($app->status === 'pending' && $bunny->enabled()) {
            $stale = $app->samples->filter(fn (ApplicationSample $s) => $s->status === 'processing'
                || ($s->status === 'uploading' && $s->updated_at?->lt(now()->subSeconds(30))));
            foreach ($stale as $sample) {
                $bunny->syncSample($sample);
            }
        }

        return $this->ok($this->present($app));
    }

    /** POST me/studio-application/samples: creates a Bunny video and returns TUS credentials for one sample. */
    public function storeSample(Request $request, BunnyStream $bunny): JsonResponse
    {
        $data = $request->validate([
            'title' => ['nullable', 'string', 'max:150'],
            'size_bytes' => ['nullable', 'integer', 'min:1', 'max:'.ApplicationSample::MAX_BYTES],
        ]);
        $bunny->ensureEnabled();
        $app = $this->openApplication($request);
        if ($app->samples->count() >= StudioApplication::REQUIRED_SAMPLES) {
            throw new ApiException(__('api.samples_full'), 'samples_full', 422);
        }

        $title = trim((string) ($data['title'] ?? '')) ?: 'Sample '.($app->samples->count() + 1);
        $bunnyTitle = 'Application '.$app->id.' - '.$title;
        $guid = (string) $bunny->createVideo($bunnyTitle)['guid'];
        $sample = $app->samples()->create(['bunny_video_id' => $guid, 'title' => $title, 'status' => 'uploading']);

        return $this->ok([
            'sample' => $sample->toPublicArray(),
            'upload' => $bunny->uploadCredentials($guid, $bunnyTitle),
        ], null, 201);
    }

    /** POST me/studio-application/samples/{sample}/complete: the TUS upload finished on the client. */
    public function completeSample(Request $request, BunnyStream $bunny, int $sample): JsonResponse
    {
        $request->validate(['video_id' => ['nullable', 'string', 'max:64']]);
        $app = $this->openApplication($request);
        $model = $app->samples->firstWhere('id', $sample) ?? abort(404);
        if ($request->filled('video_id') && strcasecmp($request->input('video_id'), (string) $model->bunny_video_id) !== 0) {
            throw new ApiException(__('api.video_upload_mismatch'), 'video_upload_mismatch', 409);
        }
        if ($model->status === 'uploading') {
            $model->update(['status' => 'processing']);
        }
        $bunny->syncSample($model);

        return $this->ok($model->toPublicArray());
    }

    /** DELETE me/studio-application/samples/{sample}: remove a sample (to replace it) before review. */
    public function destroySample(Request $request, BunnyStream $bunny, int $sample): JsonResponse
    {
        $app = $this->openApplication($request);
        $model = $app->samples->firstWhere('id', $sample) ?? abort(404);
        $bunny->deleteVideo($model->bunny_video_id);
        $model->delete();

        return $this->ok(['deleted' => true]);
    }
}
