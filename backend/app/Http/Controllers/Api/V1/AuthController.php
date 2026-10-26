<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'] ?? null,
            'phone' => $data['phone'] ?? null,
            'password' => $data['password'],
            'role' => User::ROLE_VIEWER,
            'coins' => 0,
            'status' => 'active',
        ]);

        return $this->ok([
            'token' => $user->createToken($request->input('device_name', 'api'))->plainTextToken,
            'user' => new UserResource($user->load('company')),
        ], null, 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $login = trim($request->input('login'));
        $user = User::query()
            ->where('email', $login)
            ->orWhere('phone', $login)
            ->first();

        if (! $user || ! Hash::check($request->input('password'), $user->password)) {
            throw new ApiException('Barua pepe/namba ya simu au nenosiri si sahihi.', 'invalid_credentials', 401);
        }
        if ($user->status !== 'active') {
            throw new ApiException('Akaunti yako imesimamishwa.', 'account_suspended', 403);
        }

        return $this->ok([
            'token' => $user->createToken($request->input('device_name', 'api'))->plainTextToken,
            'user' => new UserResource($user->load('company')),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return $this->ok(['message' => 'Umetoka.']);
    }

    public function me(Request $request): JsonResponse
    {
        return $this->ok(new UserResource($request->user()->load('company')));
    }
}
