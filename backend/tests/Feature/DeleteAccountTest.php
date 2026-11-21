<?php

namespace Tests\Feature;

use App\Models\User;

class DeleteAccountTest extends ApiTestCase
{
    public function test_viewer_can_delete_their_account_and_cannot_sign_in_again(): void
    {
        $user = $this->viewer(50, 'amina@example.com');
        $user->forceFill(['phone' => '+255712345678'])->save();
        $token = $this->tokenFor($user);

        $this->withToken($token)->deleteJson('/api/v1/me')->assertOk()->assertJsonPath('data.deleted', true);

        $user->refresh();
        $this->assertNull($user->email);
        $this->assertNull($user->phone);
        $this->assertSame('deleted', $user->status);
        $this->assertSame(0, $user->tokens()->count());

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', ['login' => 'amina@example.com', 'password' => 'password'])->assertStatus(401);
        // The email can be used for a new account.
        $this->postJson('/api/v1/auth/register', ['name' => 'Amina', 'email' => 'amina@example.com', 'password' => 'secret12', 'password_confirmation' => 'secret12'])->assertCreated();
    }

    public function test_studio_and_admin_accounts_are_closed_by_support(): void
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'boss@afriva.com', 'password' => 'password', 'role' => 'super_admin']);
        $this->withToken($this->tokenFor($admin))->deleteJson('/api/v1/me')->assertStatus(403)->assertJsonPath('code', 'account_delete_contact');
    }
}
