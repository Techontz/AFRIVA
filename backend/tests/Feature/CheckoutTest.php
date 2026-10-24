<?php

namespace Tests\Feature;

use App\Models\Plan;

class CheckoutTest extends ApiTestCase
{
    public function test_sandbox_checkout_activates_subscription_and_episode_plays(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $locked = $this->episode(8);
        $plan = Plan::where('type', 'monthly')->firstOrFail();

        $this->withToken($token)->getJson("/api/v1/episodes/{$locked->id}/play")->assertStatus(402);

        $res = $this->withToken($token)->postJson('/api/v1/checkout', [
            'plan_id' => $plan->id, 'payment_method' => 'mpesa', 'phone' => '+255712345678',
        ]);
        $res->assertCreated()
            ->assertJsonStructure(['data' => ['payment' => ['reference', 'status', 'amount', 'currency'], 'message', 'next_action']])
            ->assertJsonPath('data.payment.status', 'success')
            ->assertJsonPath('data.payment.amount', 10000)
            ->assertJsonPath('data.payment.currency', 'TZS')
            ->assertJsonPath('data.next_action', 'none');

        $reference = $res->json('data.payment.reference');
        $this->withToken($token)->getJson("/api/v1/payments/{$reference}")->assertOk()->assertJsonPath('data.status', 'success');

        $this->withToken($token)->getJson('/api/v1/me/subscription')->assertOk()
            ->assertJsonPath('data.type', 'monthly')
            ->assertJsonPath('data.is_active', true)
            ->assertJsonPath('meta.is_vip', true);
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertJsonPath('data.active_subscription.type', 'monthly');

        $this->withToken($token)->getJson("/api/v1/episodes/{$locked->id}/play")->assertOk()
            ->assertJsonPath('data.video_url', 'https://videos.example.com/8.mp4');
    }

    public function test_checkout_pending_when_sandbox_auto_approve_disabled(): void
    {
        config(['payments.sandbox.auto_approve' => false]);
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'weekly')->firstOrFail();

        $res = $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'visa'])
            ->assertCreated()
            ->assertJsonPath('data.payment.status', 'pending')
            ->assertJsonPath('data.message', 'Pending — payment provider not yet connected.');

        $this->assertNull($user->activeTimeSubscription());

        // Callback for a non-connected provider is accepted but does nothing.
        $this->postJson('/api/v1/payments/callback/mpesa', ['reference' => $res->json('data.payment.reference')])
            ->assertOk()->assertJsonPath('data.received', true);
        $this->postJson('/api/v1/payments/callback/unknown')->assertNotFound()->assertJsonPath('code', 'unknown_provider');
    }

    public function test_coin_pack_adds_coins(): void
    {
        $user = $this->viewer(coins: 10);
        $plan = Plan::where('name', '550 Coins')->firstOrFail();

        $this->withToken($this->tokenFor($user))->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'airtelmoney', 'phone' => '+255680000000'])
            ->assertCreated()->assertJsonPath('data.user_coins', 560);
    }

    public function test_mobile_money_requires_phone(): void
    {
        $user = $this->viewer();
        $plan = Plan::where('type', 'weekly')->firstOrFail();
        $this->withToken($this->tokenFor($user))->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'mpesa'])
            ->assertStatus(422)->assertJsonPath('code', 'validation_error');
    }

    public function test_earnings_distribute_command_splits_pool_by_subscriber_views(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'monthly')->firstOrFail();
        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'mpesa', 'phone' => '+255712345678']);
        $this->withToken($token)->getJson('/api/v1/episodes/'.$this->episode(9)->id.'/play')->assertOk();

        $this->artisan('earnings:distribute', ['--date' => now()->toDateString()])->assertSuccessful();

        // 10000 / 30 days × 100% of views × 70% = 233
        $this->assertDatabaseHas('company_earnings', ['company_id' => $this->company->id, 'source' => 'subscription_pool', 'amount' => 233]);
    }
}
