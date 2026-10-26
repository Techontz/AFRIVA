<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\DramaResource;
use App\Models\Drama;
use App\Services\ReviewService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Publishing rules (scope §05): date (now or scheduled), free episodes, coin price, VIP access. */
class PublishController extends Controller
{
    public function __construct(protected ReviewService $reviews) {}

    public function publish(Request $request, int $drama): JsonResponse
    {
        $data = $request->validate([
            'publish_at' => ['nullable', 'date'],
            'free_episodes' => ['sometimes', 'integer', 'min:0', 'max:1000'],
            'coins_per_episode' => ['sometimes', 'integer', 'min:0', 'max:100000'],
            'access_mode' => ['sometimes', Rule::in(Drama::ACCESS_MODES)],
            'is_featured' => ['sometimes', 'boolean'],
            'badge' => ['nullable', Rule::in(['hot', 'new', 'vip'])],
        ]);
        $model = $this->reviews->publish(Drama::findOrFail($drama), $request->user(), $data);

        return $this->ok((new DramaResource($model->load(['categories', 'tags', 'company'])))->withReview());
    }

    public function unpublish(Request $request, int $drama): JsonResponse
    {
        $model = $this->reviews->unpublish(Drama::findOrFail($drama), $request->user());

        return $this->ok((new DramaResource($model->load(['categories', 'tags', 'company'])))->withReview());
    }
}
