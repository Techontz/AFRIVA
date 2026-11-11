<?php

namespace Tests\Feature;

use App\Models\Plan;
use App\Models\SavedPaymentMethod;
use App\Payments\MobileNetwork;

class SavedPaymentMethodTest extends ApiTestCase
{
    public function test_network_is_detected_from_the_number(): void
    {
        $this->assertSame('255754123456', MobileNetwork::normalize('0754 123 456'));
        $this->assertSame('255754123456', MobileNetwork::normalize('+255 754 123 456'));
        $this->assertNull(MobileNetwork::normalize('12345'));
        $this->assertSame('mpesa', MobileNetwork::methodFor('255754123456'));
        $this->assertSame('airtelmoney', MobileNetwork::methodFor('255688123456'));
        $this->assertSame('tigopesa', MobileNetwork::methodFor('255714123456'));
        $this->assertSame('halopesa', MobileNetwork::methodFor('255621123456'));
    }

    public function test_options_report_channels(): void
    {
        $this->getJson('/api/v1/checkout/options')->assertOk()
            ->assertJsonPath('data.mobile_money.available', true)
            ->assertJsonPath('data.card.available', true)
            ->assertJsonPath('data.demo', true);

        config(['payments.sandbox.auto_approve' => false]);
        $this->getJson('/api/v1/checkout/options')->assertOk()
            ->assertJsonPath('data.mobile_money.available', false)
            ->assertJsonPath('data.card.available', false);
    }

    public function test_mobile_money_by_number_is_saved_and_can_be_reused_with_one_tap(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'monthly')->firstOrFail();

        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0754 123 456'])
            ->assertCreated()->assertJsonPath('data.payment.status', 'success')
            ->assertJsonPath('data.payment.payment_method', 'mpesa')
            ->assertJsonPath('data.payment.phone', '255754123456');

        $saved = $this->withToken($token)->getJson('/api/v1/me/payment-methods')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.type', 'mobile_money')
            ->assertJsonPath('data.0.phone', '255754123456')
            ->assertJsonPath('data.0.method_code', 'mpesa')
            ->assertJsonPath('data.0.is_default', true)
            ->assertJsonPath('data.0.one_tap', true)
            ->json('data.0.id');

        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'saved_method_id' => $saved])
            ->assertCreated()->assertJsonPath('data.payment.status', 'success')->assertJsonPath('data.payment.phone', '255754123456');

        // Paying with the same number again does not duplicate it.
        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '+255754123456']);
        $this->assertSame(1, SavedPaymentMethod::where('user_id', $user->id)->count());
    }

    public function test_save_can_be_turned_off(): void
    {
        $user = $this->viewer();
        $plan = Plan::where('type', 'weekly')->firstOrFail();
        $this->withToken($this->tokenFor($user))->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0688123456', 'save' => false])
            ->assertCreated()->assertJsonPath('data.payment.payment_method', 'airtelmoney');
        $this->assertSame(0, SavedPaymentMethod::where('user_id', $user->id)->count());
    }

    public function test_card_saves_only_brand_last4_and_expiry_and_full_numbers_are_refused(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'monthly')->firstOrFail();
        $year = (int) now()->addYears(2)->format('Y');

        $this->withToken($token)->postJson('/api/v1/checkout', [
            'plan_id' => $plan->id, 'channel' => 'card',
            'card' => ['brand' => 'visa', 'last4' => '4242', 'exp_month' => 12, 'exp_year' => $year, 'number' => '4242424242424242', 'cvc' => '123'],
        ])->assertStatus(422)->assertJsonValidationErrors(['card.number', 'card.cvc']);

        $this->withToken($token)->postJson('/api/v1/checkout', [
            'plan_id' => $plan->id, 'channel' => 'card', 'card' => ['brand' => 'visa', 'last4' => '4242', 'exp_month' => 1, 'exp_year' => 2020],
        ])->assertStatus(422);

        $this->withToken($token)->postJson('/api/v1/checkout', [
            'plan_id' => $plan->id, 'channel' => 'card', 'card' => ['brand' => 'visa', 'last4' => '4242', 'exp_month' => 12, 'exp_year' => $year],
        ])->assertCreated()->assertJsonPath('data.payment.status', 'success')->assertJsonPath('data.payment.payment_method', 'visa');

        $this->withToken($token)->getJson('/api/v1/me/payment-methods')
            ->assertJsonPath('data.0.type', 'card')
            ->assertJsonPath('data.0.card_brand', 'visa')
            ->assertJsonPath('data.0.card_last4', '4242')
            ->assertJsonPath('data.0.card_exp_year', $year)
            ->assertJsonMissingPath('data.0.provider_token');
    }

    public function test_unknown_or_invalid_numbers_are_refused(): void
    {
        $token = $this->tokenFor($this->viewer());
        $plan = Plan::where('type', 'weekly')->firstOrFail();
        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '12345'])
            ->assertStatus(422)->assertJsonValidationErrors('phone');
        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0721123456'])
            ->assertStatus(422)->assertJsonValidationErrors('phone');
    }

    public function test_methods_whose_gateway_is_not_connected_are_refused_instead_of_hanging(): void
    {
        config(['payments.sandbox.auto_approve' => false]);
        $token = $this->tokenFor($this->viewer());
        $plan = Plan::where('type', 'weekly')->firstOrFail();
        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'channel' => 'mobile_money', 'phone' => '0754123456'])
            ->assertStatus(422)->assertJsonValidationErrors('phone');
    }

    public function test_saved_methods_are_private_and_can_be_added_defaulted_and_removed(): void
    {
        $owner = $this->viewer();
        $other = $this->viewer(0, 'other@afriva.co.tz');
        $ownerToken = $this->tokenFor($owner);
        $plan = Plan::where('type', 'weekly')->firstOrFail();

        $first = $this->withToken($ownerToken)->postJson('/api/v1/me/payment-methods', ['phone' => '0754123456'])->assertCreated()->json('data.id');
        $second = $this->withToken($ownerToken)->postJson('/api/v1/me/payment-methods', ['phone' => '0688123456'])->assertCreated()
            ->assertJsonPath('data.is_default', true)->json('data.id');
        $this->withToken($ownerToken)->patchJson("/api/v1/me/payment-methods/{$first}")->assertOk()->assertJsonPath('data.is_default', true);

        $otherToken = $this->tokenFor($other);
        $this->app['auth']->forgetGuards(); // the test client keeps the first user signed in otherwise
        $this->withToken($otherToken)->getJson('/api/v1/me/payment-methods')->assertJsonCount(0, 'data');
        $this->withToken($otherToken)->deleteJson("/api/v1/me/payment-methods/{$first}")->assertNotFound();
        $this->withToken($otherToken)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'saved_method_id' => $first])->assertStatus(422);

        $this->app['auth']->forgetGuards();
        $this->withToken($ownerToken)->deleteJson("/api/v1/me/payment-methods/{$first}")->assertOk();
        $this->withToken($ownerToken)->getJson('/api/v1/me/payment-methods')->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $second)->assertJsonPath('data.0.is_default', true);
    }
}
