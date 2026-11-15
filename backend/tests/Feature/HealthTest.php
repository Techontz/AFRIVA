<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;

class HealthTest extends ApiTestCase
{
    public function test_health_reports_every_check_and_no_secrets(): void
    {
        config(['app.version' => '1.4.0', 'app.commit' => 'abc1234', 'services.bunny.library_id' => null]);
        Storage::fake('public');

        $res = $this->getJson('/api/v1/health')->assertOk()
            ->assertJsonPath('data.status', 'ok')
            ->assertJsonPath('data.checks.database.ok', true)
            ->assertJsonPath('data.checks.cache.ok', true)
            ->assertJsonPath('data.checks.cache.store', 'array')
            ->assertJsonPath('data.checks.queue.connection', 'sync')
            ->assertJsonPath('data.checks.storage.disk', 'public')
            ->assertJsonPath('data.version', '1.4.0')
            ->assertJsonPath('data.commit', 'abc1234')
            ->assertJsonPath('data.bunny_configured', false);

        $body = $res->getContent();
        foreach (['password', 'APP_KEY', 'api_key', config('app.key')] as $secret) {
            $this->assertStringNotContainsString((string) $secret, $body);
        }
        $this->get('/up')->assertOk();
    }

    public function test_storage_problems_are_reported_but_keep_http_200(): void
    {
        config(['filesystems.disks.public.root' => '/nonexistent/afriva-health']);

        $this->getJson('/api/v1/health')->assertOk()
            ->assertJsonPath('data.status', 'degraded')
            ->assertJsonPath('data.checks.storage.ok', false)
            ->assertJsonPath('data.checks.database.ok', true);
    }

    public function test_health_returns_503_when_the_cache_store_fails(): void
    {
        config(['cache.stores.broken' => ['driver' => 'file', 'path' => '/nonexistent/afriva-health-cache', 'lock_path' => '/nonexistent/afriva-health-cache'], 'cache.default' => 'broken', 'cache.limiter' => 'array']);

        $this->getJson('/api/v1/health')->assertStatus(503)
            ->assertJsonPath('data.status', 'down')
            ->assertJsonPath('data.checks.cache.ok', false);
    }

    public function test_unconfigured_r2_and_bunny_do_not_fail_health(): void
    {
        config(['services.bunny.library_id' => null, 'filesystems.media_disk' => 'public']);
        Storage::fake('public');

        $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('data.status', 'ok')->assertJsonPath('data.bunny_configured', false);
    }

    public function test_cloud_media_disk_is_probed_with_a_cached_write(): void
    {
        config(['filesystems.media_disk' => 'r2_public']);
        Storage::fake('r2_public');

        $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('data.checks.storage.driver', 's3');
        Storage::disk('r2_public')->assertExists('.health/probe.txt');
        $this->assertSame(1, Cache::get('health:storage:r2_public'));
    }

    public function test_health_is_throttled(): void
    {
        for ($i = 0; $i < 60; $i++) {
            $this->getJson('/api/v1/health');
        }
        $this->getJson('/api/v1/health')->assertStatus(429);
    }
}
