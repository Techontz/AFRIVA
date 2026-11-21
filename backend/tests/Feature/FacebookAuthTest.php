<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Support\Facades\Http;

class FacebookAuthTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['services.facebook.app_id' => '111', 'services.facebook.app_secret' => 'secret']);
    }

    protected function fakeFacebook(array $debug = [], array $me = []): void
    {
        Http::fake([
            'graph.facebook.com/*/debug_token*' => Http::response(['data' => array_merge(['is_valid' => true, 'app_id' => '111', 'user_id' => 'fb-9'], $debug)]),
            'graph.facebook.com/*/me*' => Http::response(array_merge([
                'id' => 'fb-9', 'name' => 'Baraka Mushi', 'email' => 'Baraka@Example.com',
                'picture' => ['data' => ['url' => 'https://graph.facebook.com/pic.jpg']],
            ], $me)),
        ]);
    }

    public function test_new_facebook_user_gets_a_viewer_account_and_signing_in_again_reuses_it(): void
    {
        $this->fakeFacebook();
        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'tok'])->assertOk()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id']]])
            ->assertJsonPath('data.user.email', 'baraka@example.com');
        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'tok'])->assertOk();

        $user = User::where('facebook_id', 'fb-9')->sole();
        $this->assertSame('viewer', $user->role);
        $this->assertNotNull($user->email_verified_at);
    }

    public function test_facebook_account_without_email_still_signs_up(): void
    {
        $this->fakeFacebook(me: ['email' => null]);
        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'tok'])->assertOk();
        $this->assertNull(User::where('facebook_id', 'fb-9')->sole()->email);
    }

    public function test_existing_account_with_same_email_is_linked(): void
    {
        $existing = $this->viewer(0, 'baraka@example.com');
        $this->fakeFacebook();
        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'tok'])->assertOk()->assertJsonPath('data.user.id', $existing->id);
        $this->assertSame('fb-9', $existing->fresh()->facebook_id);
    }

    public function test_tokens_for_other_apps_or_invalid_tokens_are_rejected(): void
    {
        foreach ([['app_id' => '999'], ['is_valid' => false], ['user_id' => 'someone-else']] as $bad) {
            $this->fakeFacebook($bad);
            $this->postJson('/api/v1/auth/facebook', ['access_token' => 'tok'])->assertStatus(401)->assertJsonPath('code', 'facebook_failed');
            Http::swap(new \Illuminate\Http\Client\Factory);
        }
        $this->assertSame(0, User::where('facebook_id', 'fb-9')->count());
    }

    public function test_facebook_is_off_until_configured(): void
    {
        config(['services.facebook.app_secret' => null]);
        Http::fake();
        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'tok'])->assertStatus(401);
        Http::assertNothingSent();
    }
}
