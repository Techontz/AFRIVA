<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = User::query()->with('company');
        if ($role = $request->query('role')) {
            $q->where('role', $role);
        }
        if ($status = $request->query('status')) {
            $q->where('status', $status);
        }
        if ($companyId = $request->query('company_id')) {
            $q->where('company_id', $companyId);
        }
        if ($s = trim((string) ($request->query('search') ?? $request->query('q') ?? ''))) {
            $q->where(fn ($w) => $w->where('name', 'like', "%{$s}%")
                ->orWhere('email', 'like', "%{$s}%")
                ->orWhere('phone', 'like', "%{$s}%"));
        }

        return $this->paginated($q->orderByDesc('id')->paginate($this->perPage(25)), UserResource::class);
    }

    public function show(User $user): JsonResponse
    {
        return $this->ok(new UserResource($user->load('company')));
    }

    public function update(UpdateUserRequest $request, User $user): JsonResponse
    {
        $data = $request->validated();

        $user->fill(collect($data)->only(['name', 'status', 'role', 'company_id', 'coins', 'password'])->all());
        if (isset($data['coins_adjust'])) {
            $user->coins = max(0, (int) $user->coins + (int) $data['coins_adjust']);
        }
        $user->save();

        if (($data['status'] ?? null) === 'suspended') {
            $user->tokens()->delete();
        }

        return $this->ok(new UserResource($user->fresh('company')));
    }
}
