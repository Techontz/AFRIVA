<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\StudioApplication;
use App\Models\User;
use App\Services\FacebookToken;
use App\Services\GoogleIdToken;
use Illuminate\Support\Str;
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

        /**
     * POST /auth/google {id_token, device_name?}: sign in or sign up with Google. The ID token is checked with
     * Google; an existing account with the same verified email is linked, otherwise a viewer account is created.
     */
    public function google(Request $request, GoogleIdToken $google): JsonResponse
    {
        $request->validate(['id_token' => ['required', 'string', 'max:4096'], 'device_name' => ['nullable', 'string', 'max:100']]);

        $claims = $google->verify($request->input('id_token'));
        if (! $claims) {
            throw new ApiException(__('api.google_failed'), 'google_failed', 401);
        }

        $email = strtolower((string) $claims['email']);
        $user = User::where('google_id', $claims['sub'])->first()
            ?? User::whereRaw('LOWER(email) = ?', [$email])->first();

        if (! $user) {
            $user = User::create([
                'name' => (string) ($claims['name'] ?? Str::before($email, '@')),
                'email' => $email,
                'google_id' => (string) $claims['sub'],
                // Google accounts have no Afriva password; this random one can never be guessed or used.
                'password' => Hash::make(Str::random(48)),
                'role' => User::ROLE_VIEWER,
                'avatar_url' => $claims['picture'] ?? null,
                'status' => 'active',
            ]);
            $user->forceFill(['email_verified_at' => now()])->save();
        } elseif (! $user->google_id) {
            $user->forceFill(['google_id' => (string) $claims['sub'], 'email_verified_at' => $user->email_verified_at ?? now()])->save();
        }

        $this->ensureCanSignIn($user);

        return $this->ok([
            'token' => $user->createToken($request->input('device_name', 'google'))->plainTextToken,
            'user' => new UserResource($user->load('company')),
        ]);
    }

    /** POST /auth/facebook {access_token}: sign in or sign up with a Facebook Login access token. */
    public function facebook(Request $request, FacebookToken $facebook): JsonResponse
    {
        $request->validate(['access_token' => ['required', 'string', 'max:4096'], 'device_name' => ['nullable', 'string', 'max:100']]);

        $profile = $facebook->verify($request->input('access_token'));
        if (! $profile) {
            throw new ApiException(__('api.facebook_failed'), 'facebook_failed', 401);
        }

        $email = $profile['email'];
        $user = User::where('facebook_id', $profile['id'])->first()
            ?? ($email ? User::whereRaw('LOWER(email) = ?', [$email])->first() : null);

        if (! $user) {
            $user = User::create([
                'name' => $profile['name'] ?: 'Afriva viewer',
                'email' => $email,
                'facebook_id' => $profile['id'],
                // Facebook accounts have no Afriva password; this random one can never be guessed or used.
                'password' => Hash::make(Str::random(48)),
                'role' => User::ROLE_VIEWER,
                'avatar_url' => $profile['picture'],
                'status' => 'active',
            ]);
            if ($email) {
                $user->forceFill(['email_verified_at' => now()])->save();
            }
        } elseif (! $user->facebook_id) {
            $user->forceFill(['facebook_id' => $profile['id']])->save();
        }

        $this->ensureCanSignIn($user);

        return $this->ok([
            'token' => $user->createToken($request->input('device_name', 'facebook'))->plainTextToken,
            'user' => new UserResource($user->load('company')),
        ]);
    }

    protected function ensureCanSignIn(User $user): void
    {
        if ($user->status === 'rejected') {
            $reason = StudioApplication::where('user_id', $user->id)->latest('id')->value('rejection_reason');
            throw new ApiException($reason ? __('api.account_rejected_reason', ['reason' => $reason]) : __('api.account_rejected'), 'account_rejected', 403, ['reason' => $reason]);
        }
        if (! in_array($user->status, ['active', 'pending'], true)) {
            throw new ApiException(__('api.account_suspended'), 'account_suspended', 403);
        }
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $login = trim($request->input('login'));
        $user = User::query()
            ->where('email', $login)
            ->orWhere('phone', $login)
            ->first();

        if (! $user || ! Hash::check($request->input('password'), $user->password)) {
            throw new ApiException(__('api.invalid_credentials'), 'invalid_credentials', 401);
        }
        // Pending studio logins may sign in to follow their request and upload samples (Studio stays locked).
        if ($user->status === 'rejected') {
            $reason = StudioApplication::where('user_id', $user->id)->latest('id')->value('rejection_reason');
            throw new ApiException($reason ? __('api.account_rejected_reason', ['reason' => $reason]) : __('api.account_rejected'), 'account_rejected', 403, ['reason' => $reason]);
        }
        if (! in_array($user->status, ['active', 'pending'], true)) {
            throw new ApiException(__('api.account_suspended'), 'account_suspended', 403);
        }

        return $this->ok([
            'token' => $user->createToken($request->input('device_name', 'api'))->plainTextToken,
            'user' => new UserResource($user->load('company')),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return $this->ok(['message' => __('api.logged_out')]);
    }

    public function me(Request $request): JsonResponse
    {
        return $this->ok(new UserResource($request->user()->load('company')));
    }
}
