<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\PlanRequest;
use App\Http\Resources\PlanResource;
use App\Models\Plan;
use Illuminate\Http\JsonResponse;

class PlanController extends Controller
{
    public function index(): JsonResponse
    {
        return $this->ok(PlanResource::collection(Plan::orderBy('sort_order')->orderBy('price')->get()));
    }

    public function store(PlanRequest $request): JsonResponse
    {
        $plan = Plan::create(array_merge(['currency' => 'TZS', 'is_active' => true], $request->validated()));

        return $this->ok(new PlanResource($plan), null, 201);
    }

    public function show(Plan $plan): JsonResponse
    {
        return $this->ok(new PlanResource($plan));
    }

    public function update(PlanRequest $request, Plan $plan): JsonResponse
    {
        $plan->update($request->validated());

        return $this->ok(new PlanResource($plan));
    }

    public function destroy(Plan $plan): JsonResponse
    {
        $plan->delete();

        return $this->ok(['deleted' => true]);
    }
}
