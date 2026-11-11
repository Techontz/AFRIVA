<?php

namespace App\Http\Controllers\Api\V1\Webhooks;

use App\Http\Controllers\Controller;
use App\Models\ApplicationSample;
use App\Models\Episode;
use App\Services\BunnyStream;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Throwable;

use function Illuminate\Support\defer;

/**
 * POST /webhooks/bunny (public). Bunny Stream sends {VideoLibraryId, VideoGuid, Status, ...} on every video
 * state change. The payload is only a hint: the episode is looked up by bunny_video_id and the real state is read
 * with Get Video. Always answers 200 right away (non 2xx would be retried); the Bunny call runs after the response.
 */
class BunnyWebhookController extends Controller
{
    /** Webhook statuses that say nothing about encoding (captions, smart generation, ...). */
    protected const IGNORED_STATUSES = [9, 10, 11, 12, 13, 33];

    public function __invoke(Request $request, BunnyStream $bunny): JsonResponse
    {
        $ack = response()->json(['data' => ['received' => true]]);

        if (! $bunny->enabled()) {
            return $ack;
        }
        if (! $bunny->validWebhookSignature(
            $request->getContent(),
            $request->header('X-BunnyStream-Signature'),
            $request->header('X-BunnyStream-Signature-Version'),
            $request->header('X-BunnyStream-Signature-Algorithm'),
        )) {
            Log::notice('Bunny webhook with invalid signature ignored');

            return $ack;
        }

        $libraryId = (string) $request->input('VideoLibraryId', '');
        $guid = (string) $request->input('VideoGuid', '');
        $status = $request->input('Status');

        if ($libraryId !== $bunny->libraryId() || $guid === '' || in_array((int) $status, self::IGNORED_STATUSES, true)) {
            return $ack;
        }

        $episodeId = Episode::where('bunny_video_id', $guid)->value('id');
        if (! $episodeId) {
            // A "Request to post" sample video.
            $sampleId = ApplicationSample::where('bunny_video_id', $guid)->value('id');
            if ($sampleId) {
                defer(function () use ($bunny, $sampleId) {
                    try {
                        if ($sample = ApplicationSample::find($sampleId)) {
                            $bunny->syncSample($sample);
                        }
                    } catch (Throwable $e) {
                        Log::warning('Bunny webhook processing failed', ['sample_id' => $sampleId, 'error' => $e->getMessage()]);
                    }
                });
            }

            return $ack;
        }

        defer(function () use ($bunny, $episodeId, $guid) {
            try {
                $episode = Episode::with('drama')->find($episodeId);
                if ($episode && $episode->bunny_video_id === $guid) {
                    $bunny->syncEpisode($episode);
                }
            } catch (Throwable $e) {
                Log::warning('Bunny webhook processing failed', ['video_id' => $guid, 'error' => $e->getMessage()]);
            }
        });

        return $ack;
    }
}
