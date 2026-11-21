<?php

namespace Tests\Feature;

use App\Models\Payment;
use App\Models\Plan;
use Illuminate\Support\Facades\Http;

class SnippeGatewayTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'payments.sandbox.auto_approve' => false,
            'payments.drivers.snippe.api_key' => 'test_key',
            'payments.drivers.snippe.webhook_secret' => 'whsec_test',
            'payments.drivers.snippe.base_url' => 'https://api.snippe.test',
            'payments.methods.mpesa' => 'snippe',
            'payments.methods.airtelmoney' => 'snippe',
            'payments.methods.card' => 'snippe',
            'payments.return_url' => 'https://afriva.co.tz/vip',
        ]);
    }

    protected function signed(array $event, ?int $ts = null, ?string $secret = 'whsec_test'): array
    {
        $raw = json_encode($event);
        $ts ??= time();

        return [$raw, ['X-Webhook-Timestamp' => (string) $ts, 'X-Webhook-Signature' => hash_hmac('sha256', $ts.'.'.$raw, $secret), 'Content-Type' => 'application/json']];
    }

    public function test_mobile_money_starts_a_ussd_push_and_a_signed_webhook_activates_vip(): void
    {
        Http::fake(['api.snippe.test/v1/payments' => Http::response(['status' => 'success', 'code' => 201, 'data' => [
            'reference' => 'snp_123', 'status' => 'pending', 'payment_type' => 'mobile', 'amount' => ['value' => 10000, 'currency' => 'TZS'], 'expires_at' => 'x',
        ]], 201)]);
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'monthly')->firstOrFail();

        $res = $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0754123456'])
            ->assertCreated()->assertJsonPath('data.payment.status', 'pending')->assertJsonPath('data.next_action', 'await_ussd');

        Http::assertSent(fn ($r) => $r->url() === 'https://api.snippe.test/v1/payments'
            && $r['payment_type'] === 'mobile' && $r['phone_number'] === '+255754123456'
            && $r['details']['amount'] === 10000 && $r->hasHeader('Authorization', 'Bearer test_key')
            && str_ends_with($r['webhook_url'], '/snippe') && $r->hasHeader('Idempotency-Key'));

        $ref = $res->json('data.payment.reference');
        [$raw, $headers] = $this->signed(['id' => 'evt_1', 'type' => 'payment.completed', 'data' => [
            'reference' => 'snp_123', 'status' => 'completed', 'amount' => ['value' => 10000, 'currency' => 'TZS'],
        ]]);
        $this->call('POST', '/api/v1/payments/callback/snippe', [], [], [], $this->transformHeadersToServerVars($headers), $raw)
            ->assertOk()->assertJsonPath('data.status', 'success');

        $this->assertSame('success', Payment::where('reference', $ref)->value('status'));
        $this->assertNotNull($user->fresh()->activeTimeSubscription());
    }

    public function test_forged_stale_or_wrong_amount_webhooks_are_ignored(): void
    {
        Http::fake(['api.snippe.test/v1/payments' => Http::response(['data' => ['reference' => 'snp_9', 'status' => 'pending']], 201)]);
        $user = $this->viewer();
        $plan = Plan::where('type', 'monthly')->firstOrFail();
        $this->withToken($this->tokenFor($user))->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0688123456'])->assertCreated();

        $event = ['id' => 'e', 'type' => 'payment.completed', 'data' => ['reference' => 'snp_9', 'amount' => ['value' => 10000]]];
        foreach ([
            $this->signed($event, null, 'wrong_secret'),
            $this->signed($event, time() - 3600),
            $this->signed(['id' => 'e', 'type' => 'payment.completed', 'data' => ['reference' => 'snp_9', 'amount' => ['value' => 1]]]),
        ] as [$raw, $headers]) {
            $this->call('POST', '/api/v1/payments/callback/snippe', [], [], [], $this->transformHeadersToServerVars($headers), $raw)->assertOk();
        }

        $this->assertSame('pending', Payment::where('provider_reference', 'snp_9')->value('status'));
        $this->assertNull($user->fresh()->activeTimeSubscription());
    }

    public function test_card_goes_to_the_hosted_page_without_card_details(): void
    {
        Http::fake(['api.snippe.test/v1/payments' => Http::response(['data' => [
            'reference' => 'snp_card', 'status' => 'pending', 'payment_type' => 'card', 'payment_url' => 'https://pay.snippe.test/c/abc',
        ]], 201)]);
        $user = $this->viewer();
        $plan = Plan::where('type', 'weekly')->firstOrFail();

        $this->withToken($this->tokenFor($user))->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'card', 'phone' => '0754123456'])
            ->assertCreated()->assertJsonPath('data.next_action', 'redirect')
            ->assertJsonPath('data.redirect_url', 'https://pay.snippe.test/c/abc')
            ->assertJsonPath('data.payment.payment_method', 'card');

        Http::assertSent(fn ($r) => $r['payment_type'] === 'card' && $r['customer']['country'] === 'TZ'
            && str_starts_with($r['details']['redirect_url'], 'https://afriva.co.tz/vip?payment=AFV-')
            && ! isset($r['card']));
    }

    public function test_checkout_options_report_snippe_methods_as_available(): void
    {
        $this->getJson('/api/v1/checkout/options')->assertOk()
            ->assertJsonPath('data.mobile_money.available', true)
            ->assertJsonPath('data.card.available', true)
            ->assertJsonPath('data.card.hosted', true);
    }

    public function test_polling_asks_snippe_for_the_status(): void
    {
        Http::fake([
            'api.snippe.test/v1/payments' => Http::response(['data' => ['reference' => 'snp_poll', 'status' => 'pending']], 201),
            'api.snippe.test/v1/payments/snp_poll' => Http::response(['data' => ['reference' => 'snp_poll', 'status' => 'completed']]),
        ]);
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'weekly')->firstOrFail();
        $ref = $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0754123456'])->json('data.payment.reference');

        $this->withToken($token)->getJson("/api/v1/payments/{$ref}")->assertOk()->assertJsonPath('data.status', 'success');
        $this->assertNotNull($user->fresh()->activeTimeSubscription());
    }
}
