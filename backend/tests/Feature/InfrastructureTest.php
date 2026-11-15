<?php

namespace Tests\Feature;

use App\Mail\ErrorAlert;
use App\Mail\InfraBudgetAlert;
use App\Models\Episode;
use App\Models\Setting;
use App\Models\User;
use App\Services\Infra\InfraMetrics;
use App\Support\ErrorAlerter;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;

class InfrastructureTest extends ApiTestCase
{
    protected function adminToken(): string
    {
        return $this->tokenFor(User::firstOrCreate(['email' => 'admin@afriva.com'], ['name' => 'Admin', 'password' => 'password', 'role' => 'super_admin']));
    }

    protected function connectAll(): void
    {
        config([
            'infra.hetzner.token' => 'h-token', 'infra.hetzner.server_id' => '42',
            'services.bunny.library_id' => '123', 'services.bunny.api_key' => 'lib-key',
            'services.bunny.cdn_hostname' => 'vz-test.b-cdn.net', 'infra.bunny.account_api_key' => 'acct-key',
            'infra.r2.api_token' => 'cf-token', 'infra.r2.account_id' => 'acc123', 'infra.r2.buckets' => ['afriva-media', 'afriva-private'],
        ]);
        Http::preventStrayRequests();
        Http::fake([
            'api.hetzner.cloud/v1/servers/42' => Http::response(['server' => [
                'name' => 'afriva-prod', 'status' => 'running', 'backup_window' => '22-02',
                'location' => ['name' => 'nbg1'],
                'server_type' => ['name' => 'cx33', 'cores' => 4, 'memory' => 8.0, 'disk' => 80, 'prices' => [
                    ['location' => 'fsn1', 'price_monthly' => ['net' => '9.0000', 'gross' => '9.0000'], 'included_traffic' => 20000000000000],
                    ['location' => 'nbg1', 'price_monthly' => ['net' => '10.0000', 'gross' => '10.0000'], 'included_traffic' => 20000000000000],
                ]],
            ]]),
            'api.hetzner.cloud/v1/pricing' => Http::response(['pricing' => ['currency' => 'EUR', 'server_backup' => ['percentage' => '20.00']]]),
            'video.bunnycdn.com/library/123/videos*' => Http::response(['totalItems' => 7, 'items' => [['storageSize' => 1000]]]),
            'api.bunny.net/videolibrary/123' => Http::response(['StorageUsage' => 5_000_000_000, 'TrafficUsage' => 3_000_000_000, 'VideoCount' => 7]),
            'api.bunny.net/statistics*' => Http::response(['TotalBandwidthUsed' => 20_000_000_000, 'TotalRequestsServed' => 1000, 'CacheHitRate' => 91.5]),
            'api.bunny.net/billing' => Http::response(['Balance' => 50.5, 'ThisMonthCharges' => 4.0, 'MonthlyChargesAFTraffic' => 3.5, 'MonthlyChargesStorage' => 0.5]),
            'api.cloudflare.com/client/v4/accounts/acc123/r2/metrics' => Http::response(['success' => true, 'result' => [
                'standard' => ['published' => ['objects' => 120, 'payloadSize' => 2_000_000_000, 'metadataSize' => 1000], 'uploaded' => []],
            ]]),
            'api.cloudflare.com/client/v4/graphql' => Http::response(['data' => ['viewer' => ['accounts' => [[
                'storage' => [
                    ['max' => ['objectCount' => 100, 'payloadSize' => 1_900_000_000, 'metadataSize' => 0], 'dimensions' => ['bucketName' => 'afriva-media', 'datetime' => '2026-11-15T10:00:00Z']],
                    ['max' => ['objectCount' => 90, 'payloadSize' => 1_800_000_000, 'metadataSize' => 0], 'dimensions' => ['bucketName' => 'afriva-media', 'datetime' => '2026-11-15T09:00:00Z']],
                ],
                'operations' => [
                    ['sum' => ['requests' => 5000], 'dimensions' => ['actionType' => 'PutObject']],
                    ['sum' => ['requests' => 90000], 'dimensions' => ['actionType' => 'GetObject']],
                    ['sum' => ['requests' => 10], 'dimensions' => ['actionType' => 'DeleteObject']],
                ],
            ]]]]]),
        ]);
    }

    public function test_only_super_admins_can_read_the_snapshot(): void
    {
        $this->getJson('/api/v1/admin/infrastructure')->assertStatus(401);
        $this->withToken($this->tokenFor($this->viewer()))->getJson('/api/v1/admin/infrastructure')->assertStatus(403);
        $this->app['auth']->forgetGuards();
        $studio = User::where('email', 'kilima-studios@afriva.com')->first();
        $this->withToken($this->tokenFor($studio))->getJson('/api/v1/admin/infrastructure')->assertStatus(403);
    }

    public function test_unconfigured_providers_are_not_called_and_name_their_env_variables(): void
    {
        config(['services.bunny.library_id' => null, 'infra.hetzner.token' => null, 'infra.r2.api_token' => null]);
        Http::preventStrayRequests();
        Episode::query()->limit(2)->update(['video_status' => 'failed']);

        $res = $this->withToken($this->adminToken())->getJson('/api/v1/admin/infrastructure')->assertOk()
            ->assertJsonPath('data.sections.hetzner.configured', false)
            ->assertJsonPath('data.sections.hetzner.env', ['HETZNER_API_TOKEN', 'HETZNER_SERVER_ID'])
            ->assertJsonPath('data.sections.r2.configured', false)
            ->assertJsonPath('data.sections.r2.env', ['CLOUDFLARE_API_TOKEN', 'CLOUDFLARE_ACCOUNT_ID'])
            ->assertJsonPath('data.sections.bunny.configured', false)
            ->assertJsonPath('data.sections.server.ok', true)
            ->assertJsonPath('data.sections.database.data.driver', 'sqlite')
            ->assertJsonPath('data.sections.app.data.episodes_failed', 2)
            ->assertJsonPath('data.cost.complete', false)
            ->assertJsonPath('data.budget.monthly_budget_usd', null);

        foreach ($res->json('data.sections') as $section) {
            $this->assertArrayHasKey('source', $section);
            $this->assertArrayHasKey('as_of', $section);
        }
        foreach ($res->json('data.cost.lines') as $line) {
            $this->assertContains($line['tag'], ['live_usage', 'estimate', 'billed']);
        }
        $this->assertSame('not_connected', collect($res->json('data.cost.lines'))->firstWhere('provider', 'bunny')['basis']);
    }

    public function test_connected_providers_feed_usage_and_cost(): void
    {
        $this->connectAll();
        config(['infra.monthly_budget_usd' => 100, 'infra.eur_to_usd' => 1.0, 'infra.fixed.vercel' => 20]);

        $res = $this->withToken($this->adminToken())->getJson('/api/v1/admin/infrastructure')->assertOk()
            ->assertJsonPath('data.sections.hetzner.data.server_type', 'cx33')
            ->assertJsonPath('data.sections.hetzner.data.location', 'nbg1')
            ->assertJsonPath('data.sections.hetzner.data.price_monthly_gross_eur', 10)
            ->assertJsonPath('data.sections.bunny.data.video_count', 7)
            ->assertJsonPath('data.sections.bunny.data.storage_bytes', 5_000_000_000)
            ->assertJsonPath('data.sections.bunny.data.bandwidth_month_bytes', 20_000_000_000)
            ->assertJsonPath('data.sections.bunny.data.billing.this_month_charges', 4)
            ->assertJsonPath('data.sections.bunny.data.billing.balance', 50.5)
            ->assertJsonPath('data.sections.r2.data.object_count', 120)
            ->assertJsonPath('data.sections.r2.data.buckets.0.name', 'afriva-media')
            ->assertJsonPath('data.sections.r2.data.buckets.0.object_count', 100)
            ->assertJsonPath('data.sections.r2.data.buckets.1.object_count', 0)
            ->assertJsonPath('data.sections.r2.data.class_a_month', 5000)
            ->assertJsonPath('data.sections.r2.data.class_b_month', 90000)
            ->assertJsonPath('data.budget.monthly_budget_usd', 100);

        $lines = collect($res->json('data.cost.lines'))->keyBy('provider');
        $this->assertEquals(12.0, $lines['hetzner']['amount_usd']); // 10 EUR + 20% backups
        $this->assertSame('hetzner_list_price', $lines['hetzner']['basis']);
        $this->assertSame('projected_from_billed', $lines['bunny']['basis']);
        $this->assertEquals(4.0, $lines['bunny']['billed_to_date_usd']);
        $this->assertSame('billed', $lines['bunny']['billed_tag']);
        $this->assertEquals(0.0, $lines['r2']['amount_usd']); // inside the free tier
        $this->assertTrue($res->json('data.cost.complete'));

        // Cached: a second call makes no new provider requests.
        $count = count(Http::recorded());
        $this->withToken($this->adminToken())->getJson('/api/v1/admin/infrastructure')->assertOk();
        $this->assertCount($count, Http::recorded());
        Http::assertSent(fn ($r) => $r->hasHeader('AccessKey', 'acct-key') && str_contains($r->url(), 'api.bunny.net/billing'));
        Http::assertSent(fn ($r) => $r->hasHeader('Authorization', 'Bearer h-token'));
    }

    public function test_provider_failures_are_reported_per_section_without_breaking_the_page(): void
    {
        config(['infra.hetzner.token' => 't', 'infra.hetzner.server_id' => '1', 'services.bunny.library_id' => null, 'infra.r2.api_token' => null]);
        Http::preventStrayRequests();
        Http::fake(['api.hetzner.cloud/*' => Http::response(['error' => ['message' => 'unauthorized']], 401)]);

        $this->withToken($this->adminToken())->getJson('/api/v1/admin/infrastructure?refresh=1')->assertOk()
            ->assertJsonPath('data.sections.hetzner.configured', true)
            ->assertJsonPath('data.sections.hetzner.ok', false)
            ->assertJsonPath('data.sections.hetzner.error', 'HTTP 401')
            ->assertJsonPath('data.sections.server.ok', true);

        $line = collect(app(InfraMetrics::class)->snapshot()['cost']['lines'])->firstWhere('provider', 'hetzner');
        $this->assertSame('config_price', $line['basis']);
    }

    public function test_budget_setting_overrides_env_and_is_editable_in_settings(): void
    {
        config(['infra.monthly_budget_usd' => 100]);
        $this->withToken($this->adminToken())->putJson('/api/v1/admin/settings', ['infra_monthly_budget_usd' => 40])->assertOk();
        $this->assertEquals(40, Setting::allAsArray()['infra_monthly_budget_usd']);
        $this->assertSame(40.0, app(InfraMetrics::class)->budgetUsd());
        $this->withToken($this->adminToken())->putJson('/api/v1/admin/settings', ['infra_monthly_budget_usd' => -5])->assertStatus(422);
    }

    public function test_budget_alerts_send_once_per_threshold_per_month(): void
    {
        Mail::fake();
        Http::preventStrayRequests();
        config([
            'services.bunny.library_id' => null, 'infra.hetzner.token' => null, 'infra.r2.api_token' => null,
            'infra.alert_email' => 'ops@afriva.co.tz', 'infra.eur_to_usd' => 1.0,
            'infra.hetzner.fallback_monthly_eur' => 0, 'infra.fixed.cloudflare' => 0,
        ]);
        $this->travelTo(now()->setDate(2026, 11, 15));
        $setSpend = fn (float $usd) => config(['infra.fixed.vercel' => $usd]);
        config(['infra.monthly_budget_usd' => 100]);

        $setSpend(40);
        $this->artisan('infra:check-budget')->expectsOutputToContain('no new threshold')->assertSuccessful();
        Mail::assertNothingSent();

        $setSpend(60);
        $this->artisan('infra:check-budget')->expectsOutputToContain('Alert sent for 50%')->assertSuccessful();
        $this->artisan('infra:check-budget')->assertSuccessful();
        Mail::assertSent(InfraBudgetAlert::class, 1);

        // Jumping past 75 and 90 at once: one email naming the highest threshold.
        $setSpend(95);
        $this->artisan('infra:check-budget')->assertSuccessful();
        Mail::assertSent(InfraBudgetAlert::class, 2);
        Mail::assertSent(InfraBudgetAlert::class, fn (InfraBudgetAlert $m) => $m->threshold === 90 && $m->hasTo('ops@afriva.co.tz'));
        $this->artisan('infra:check-budget')->assertSuccessful();
        Mail::assertSent(InfraBudgetAlert::class, 2);

        $setSpend(120);
        $this->artisan('infra:check-budget')->assertSuccessful();
        Mail::assertSent(InfraBudgetAlert::class, fn (InfraBudgetAlert $m) => $m->threshold === 100);
        Mail::assertSent(InfraBudgetAlert::class, 3);

        // The state row is hidden from the settings API.
        $this->assertArrayNotHasKey('infra_budget_alerts', Setting::allAsArray());

        // A new month starts over.
        $this->travelTo(now()->setDate(2026, 12, 2));
        $this->artisan('infra:check-budget')->assertSuccessful();
        Mail::assertSent(InfraBudgetAlert::class, fn (InfraBudgetAlert $m) => $m->threshold === 100 && $m->budget['month'] === '2026-12');
        Mail::assertSent(InfraBudgetAlert::class, 4);
    }

    public function test_budget_check_is_a_no_op_without_a_budget_and_is_scheduled_hourly(): void
    {
        Mail::fake();
        config(['infra.monthly_budget_usd' => null, 'services.bunny.library_id' => null, 'infra.hetzner.token' => null, 'infra.r2.api_token' => null]);
        $this->artisan('infra:check-budget')->expectsOutputToContain('No monthly budget')->assertSuccessful();
        Mail::assertNothingSent();

        $event = collect(app(Schedule::class)->events())
            ->first(fn ($e) => str_contains((string) $e->command, 'infra:check-budget'));
        $this->assertNotNull($event);
        $this->assertSame('0 * * * *', $event->expression);
    }

    public function test_error_alerts_are_throttled_per_exception_class(): void
    {
        Mail::fake();
        config(['infra.alert_email' => 'ops@afriva.co.tz', 'mail.default' => 'smtp']);

        ErrorAlerter::report(new \RuntimeException('boom 1'));
        ErrorAlerter::report(new \RuntimeException('boom 2'));
        ErrorAlerter::report(new \LogicException('other'));
        Mail::assertSent(ErrorAlert::class, 2);

        $this->travel(11)->minutes();
        ErrorAlerter::report(new \RuntimeException('boom 3'));
        Mail::assertSent(ErrorAlert::class, 3);
    }

    public function test_error_alerts_are_off_without_a_real_mailer_or_email(): void
    {
        Mail::fake();
        config(['infra.alert_email' => 'ops@afriva.co.tz', 'mail.default' => 'log']);
        ErrorAlerter::report(new \RuntimeException('x'));
        config(['infra.alert_email' => null, 'mail.default' => 'smtp']);
        ErrorAlerter::report(new \RuntimeException('y'));
        Mail::assertNothingSent();
    }
}
