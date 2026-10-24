<?php

namespace Tests\Feature;

class AuthTest extends ApiTestCase
{
    public function test_register_returns_token_and_user(): void
    {
        $res = $this->postJson('/api/v1/auth/register', ['name' => 'Neema', 'email' => 'neema@example.com', 'password' => 'secret123']);

        $res->assertCreated()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'name', 'email', 'phone', 'role', 'coins', 'company', 'active_subscription']]])
            ->assertJsonPath('data.user.role', 'viewer')
            ->assertJsonPath('data.user.coins', 0);
    }

    public function test_register_with_phone_only(): void
    {
        $this->postJson('/api/v1/auth/register', ['name' => 'Juma', 'phone' => '+255700111222', 'password' => 'secret123'])
            ->assertCreated()->assertJsonPath('data.user.phone', '+255700111222');
    }

    public function test_register_validation_error_shape(): void
    {
        $this->postJson('/api/v1/auth/register', ['name' => 'X', 'password' => '1'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_error')
            ->assertJsonStructure(['message', 'code', 'errors' => ['email', 'password']]);
    }

    public function test_login_with_email_or_phone_and_me(): void
    {
        $this->postJson('/api/v1/auth/register', ['name' => 'Asha', 'email' => 'asha@example.com', 'phone' => '+255711000000', 'password' => 'secret123']);

        $token = $this->postJson('/api/v1/auth/login', ['login' => 'asha@example.com', 'password' => 'secret123'])
            ->assertOk()->json('data.token');
        $this->postJson('/api/v1/auth/login', ['login' => '+255711000000', 'password' => 'secret123'])->assertOk();

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'asha@example.com')
            ->assertJsonPath('data.active_subscription', null);
    }

    public function test_login_wrong_password(): void
    {
        $this->viewer();
        $this->postJson('/api/v1/auth/login', ['login' => 'viewer@afriva.com', 'password' => 'nope'])
            ->assertStatus(401)->assertJsonPath('code', 'invalid_credentials');
    }

    public function test_me_requires_auth(): void
    {
        $this->getJson('/api/v1/auth/me')->assertStatus(401)->assertJsonPath('code', 'unauthenticated');
    }
}
