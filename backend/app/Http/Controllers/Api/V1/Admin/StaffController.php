<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\AuditLog;
use App\Models\User;
use App\Support\Permissions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Staff accounts and their roles: owner, editor, reviewer, finance (owner only). */
class StaffController extends Controller
{
    public function index(): JsonResponse
    {
        return $this->ok(UserResource::collection(User::where('role', User::ROLE_SUPER_ADMIN)->orderBy('name')->get()), [
            'roles' => collect(Permissions::ROLES)->map(fn ($r) => ['role' => $r, 'permissions' => Permissions::for($r)])->values(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:190', 'unique:users,email'],
            'password' => ['required', 'string', 'min:10'],
            'staff_role' => ['required', Rule::in(Permissions::ROLES)],
        ]);
        $user = User::create($data + ['role' => User::ROLE_SUPER_ADMIN, 'status' => 'active']);
        AuditLog::record('staff.create', $user, ['staff_role' => $user->staff_role], $user->email);

        return $this->ok(new UserResource($user), null, 201);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        if (! $user->isSuperAdmin()) {
            throw new ApiException('Hakipatikani.', 'not_found', 404);
        }
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'staff_role' => ['sometimes', Rule::in(Permissions::ROLES)],
            'status' => ['sometimes', 'in:active,suspended'],
            'password' => ['sometimes', 'string', 'min:10'],
        ]);
        $losesOwner = $user->staffRole() === 'owner'
            && ((isset($data['staff_role']) && $data['staff_role'] !== 'owner') || ($data['status'] ?? 'active') !== 'active');
        if ($losesOwner) {
            $owners = User::where('role', User::ROLE_SUPER_ADMIN)->where('status', 'active')
                ->where(fn ($q) => $q->where('staff_role', 'owner')->orWhereNull('staff_role'))->count();
            if ($owners <= 1) {
                throw new ApiException('Lazima abaki angalau owner mmoja anayefanya kazi.', 'last_owner', 422);
            }
        }
        $user->fill($data)->save();
        if (($data['status'] ?? null) === 'suspended') {
            $user->tokens()->delete();
        }
        AuditLog::record('staff.update', $user, AuditLog::diff($user, ['name', 'staff_role', 'status']), $user->email);

        return $this->ok(new UserResource($user->fresh()));
    }
}
