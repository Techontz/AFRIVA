<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\AnalyticsService;
use App\Support\Viewer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * POST /events (auth optional): player analytics. Accepts one event or {events: [...]} (max 50).
 * Clients send a stable X-Device-Id header so guests count once in unique viewers / DAU.
 */
class EventController extends Controller
{
    public function store(Request $request, AnalyticsService $analytics): JsonResponse
    {
        if (! $request->has('events')) {
            $request->merge(['events' => [$request->only(['session_id', 'episode_id', 'type', 'position_seconds', 'watched_seconds', 'duration_seconds', 'quality', 'error_code'])]]);
        }
        $data = $request->validate([
            'events' => ['required', 'array', 'min:1', 'max:50'],
            'events.*.session_id' => ['required', 'string', 'max:64', 'regex:/^[A-Za-z0-9_-]+$/'],
            'events.*.episode_id' => ['required', 'integer'],
            'events.*.type' => ['required', 'in:start,heartbeat,pause,complete,error,quality'],
            'events.*.position_seconds' => ['nullable', 'integer', 'min:0', 'max:86400'],
            'events.*.watched_seconds' => ['nullable', 'integer', 'min:0', 'max:86400'],
            'events.*.duration_seconds' => ['nullable', 'integer', 'min:0', 'max:86400'],
            'events.*.quality' => ['nullable', 'string', 'max:10'],
            'events.*.error_code' => ['nullable', 'string', 'max:60'],
        ]);

        $accepted = $analytics->ingest($data['events'], Viewer::user(), $request);

        return $this->ok(['accepted' => $accepted]);
    }
}
