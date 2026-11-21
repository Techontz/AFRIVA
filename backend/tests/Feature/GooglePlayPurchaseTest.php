<?php

namespace Tests\Feature;

use App\Models\Plan;
use Illuminate\Support\Facades\Http;

class GooglePlayPurchaseTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $pem);
        config([
            'services.google_play.package' => 'com.afriva.afriva_app',
            'services.google_play.service_account' => json_encode(['client_email' => 'play@afriva.iam.gserviceaccount.com', 'private_key' => $pem]),
        ]);
        Plan::where('name', 'Weekly VIP')->update(['play_product_id' => 'afriva_vip_weekly']);
    }

    protected function fakeGoogle(int $state = 0): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3600]),
            'androidpublisher.googleapis.com/*' => Http::response(['purchaseState' => $state, 'consumptionState' => 0, 'orderId' => 'GPA.1234']),
        ]);
    }

    public function test_verified_purchase_activates_vip_once(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $this->fakeGoogle();

        $this->withToken($token)->postJson('/api/v1/payments/google-play', ['product_id' => 'afriva_vip_weekly', 'purchase_token' => 'tok-1'])
            ->assertCreated()->assertJsonPath('data.payment.status', 'success');
        $this->withToken($token)->postJson('/api/v1/payments/google-play', ['product_id' => 'afriva_vip_weekly', 'purchase_token' => 'tok-1'])
            ->assertOk();

        $this->assertSame(1, $user->subscriptions()->where('type', 'weekly')->count());
        $this->assertDatabaseHas('payments', ['user_id' => $user->id, 'payment_method_code' => 'google_play', 'status' => 'success']);
        Http::assertSent(fn ($r) => str_contains($r->url(), 'applications/com.afriva.afriva_app/purchases/products/afriva_vip_weekly/tokens/tok-1')
            && $r->hasHeader('Authorization', 'Bearer ya29.test'));
    }

    public function test_pending_or_cancelled_purchases_are_refused(): void
    {
        $user = $this->viewer();
        foreach ([1, 2] as $state) {
            $this->fakeGoogle($state);
            $this->withToken($this->tokenFor($user))->postJson('/api/v1/payments/google-play', ['product_id' => 'afriva_vip_weekly', 'purchase_token' => "tok-$state"])
                ->assertStatus(422)->assertJsonPath('code', 'play_purchase_invalid');
            Http::swap(new \Illuminate\Http\Client\Factory);
        }
        $this->assertSame(0, $user->subscriptions()->count());
    }

    public function test_a_token_cannot_be_reused_by_another_account(): void
    {
        $this->fakeGoogle();
        $this->withToken($this->tokenFor($this->viewer()))->postJson('/api/v1/payments/google-play', ['product_id' => 'afriva_vip_weekly', 'purchase_token' => 'shared'])->assertCreated();
        $other = $this->viewer(0, 'other@example.com');
        $this->app['auth']->forgetGuards();
        $this->withToken($this->tokenFor($other))->postJson('/api/v1/payments/google-play', ['product_id' => 'afriva_vip_weekly', 'purchase_token' => 'shared'])->assertStatus(422);
        $this->assertSame(0, $other->subscriptions()->count());
    }

    public function test_requires_login_and_known_product(): void
    {
        $this->postJson('/api/v1/payments/google-play', ['product_id' => 'afriva_vip_weekly', 'purchase_token' => 't'])->assertStatus(401);
        $this->withToken($this->tokenFor($this->viewer()))->postJson('/api/v1/payments/google-play', ['product_id' => 'nope', 'purchase_token' => 't'])->assertStatus(404);
    }
}
