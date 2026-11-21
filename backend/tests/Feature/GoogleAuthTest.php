<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Support\Facades\Http;

class GoogleAuthTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_ids' => ['web-client.apps.googleusercontent.com', 'android-client.apps.googleusercontent.com']]);
    }

    protected function fakeGoogle(array $overrides = []): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response(array_merge([
            'iss' => 'https://accounts.google.com', 'aud' => 'web-client.apps.googleusercontent.com', 'sub' => 'g-123',
            'email' => 'Amina@Example.com', 'email_verified' => 'true', 'name' => 'Amina Juma',
            'picture' => 'https://lh3.googleusercontent.com/a/x', 'exp' => (string) (time() + 3600),
        ], $overrides))]);
    }

    public function test_new_google_user_gets_a_viewer_account_and_token(): void
    {
        $this->fakeGoogle();
        $this->postJson('/api/v1/auth/google', ['id_token' => 'tok'])->assertOk()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'email']]])
            ->assertJsonPath('data.user.email', 'amina@example.com');

        $user = User::where('google_id', 'g-123')->firstOrFail();
        $this->assertSame('viewer', $user->role);
        $this->assertNotNull($user->email_verified_at);

        // Signing in again reuses the same account.
        $this->postJson('/api/v1/auth/google', ['id_token' => 'tok'])->assertOk();
        $this->assertSame(1, User::where('google_id', 'g-123')->count());
    }

    public function test_existing_account_with_same_email_is_linked(): void
    {
        $existing = $this->viewer(0, 'amina@example.com');
        $this->fakeGoogle();
        $this->postJson('/api/v1/auth/google', ['id_token' => 'tok'])->assertOk()->assertJsonPath('data.user.id', $existing->id);
        $this->assertSame('g-123', $existing->fresh()->google_id);
    }

    public function test_tokens_for_other_apps_unverified_emails_or_expired_are_rejected(): void
    {
        foreach ([['aud' => 'someone-else.apps.googleusercontent.com'], ['email_verified' => 'false'], ['exp' => (string) (time() - 10)], ['iss' => 'evil.example.com']] as $bad) {
            $this->fakeGoogle($bad);
            $this->postJson('/api/v1/auth/google', ['id_token' => 'tok'])->assertStatus(401)->assertJsonPath('code', 'google_failed');
            Http::swap(new \Illuminate\Http\Client\Factory);
        }
        $this->assertSame(0, User::where('google_id', 'g-123')->count());
    }

    public function test_google_is_off_when_no_client_ids_are_configured(): void
    {
        config(['services.google.client_ids' => []]);
        $this->fakeGoogle();
        $this->postJson('/api/v1/auth/google', ['id_token' => 'tok'])->assertStatus(401);
    }

    public function test_suspended_accounts_stay_blocked(): void
    {
        $user = $this->viewer(0, 'amina@example.com');
        $user->forceFill(['status' => 'suspended'])->save();
        $this->fakeGoogle();
        $this->postJson('/api/v1/auth/google', ['id_token' => 'tok'])->assertStatus(403);
    }
}
