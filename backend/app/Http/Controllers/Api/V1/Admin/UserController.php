<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\CoinLedger;
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

    public function update(UpdateUserRequest $request, User $user, CoinLedger $ledger): JsonResponse
    {
        $data = $request->validated();

        $user->fill(collect($data)->only(['name', 'status', 'role', 'company_id', 'password'])->all());
        $user->save();
        $diff = AuditLog::diff($user, ['name', 'status', 'role', 'company_id']);

        // Coin changes always go through the ledger so the balance can be explained later.
        $delta = isset($data['coins']) ? (int) $data['coins'] - (int) $user->coins : (int) ($data['coins_adjust'] ?? 0);
        if ($delta !== 0) {
            $refs = ['actor_id' => $request->user()->id];
            $note = $data['coins_reason'] ?? 'Marekebisho ya msimamizi';
            $delta > 0
                ? $ledger->credit($user, $delta, 'admin_adjust', $refs, $note)
                : $ledger->debit($user, -$delta, 'admin_adjust', $refs, $note, clamp: true);
            $diff['coins'] = ['from' => (int) $user->coins - $delta, 'to' => (int) $user->fresh()->coins];
        }
        if ($diff || isset($data['password'])) {
            AuditLog::record('user.update', $user, $diff + (isset($data['password']) ? ['password' => 'imebadilishwa'] : []), $user->email ?? $user->phone);
        }

        if (($data['status'] ?? null) === 'suspended') {
            $user->tokens()->delete();
        }

        return $this->ok(new UserResource($user->fresh('company')));
    }
}
