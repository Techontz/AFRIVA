<?php

namespace Tests\Feature;

use App\Models\Episode;
use App\Models\Payment;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Support\Facades\Storage;

/** Scope §02/§06/§07/§08: access rules, coin ledger, refunds, receipts, player analytics, HLS delivery. */
class MonetizationAnalyticsTest extends ApiTestCase
{
    protected function owner(): string
    {
        return $this->tokenFor(User::create(['name' => 'Owner', 'email' => 'owner@afriva.test', 'password' => 'password', 'role' => 'super_admin']));
    }

    public function test_episode_list_labels_free_and_locked_with_price(): void
    {
        $this->getJson("/api/v1/dramas/{$this->drama->slug}")->assertOk()
            ->assertJsonPath('data.episodes.0.access', 'free')
            ->assertJsonPath('data.episodes.3.access', 'locked')
            ->assertJsonPath('data.episodes.3.price_coins', 30);
    }

    public function test_vip_only_series_cannot_be_unlocked_with_coins(): void
    {
        $this->drama->update(['access_mode' => 'vip_only']);
        $user = $this->viewer(coins: 500);
        $ep = $this->episode(5);

        $this->withToken($this->tokenFor($user))->postJson("/api/v1/episodes/{$ep->id}/unlock", ['method' => 'coins'])
            ->assertStatus(402)->assertJsonPath('code', 'vip_required')->assertJsonPath('unlock.vip_only', true);
        $this->assertSame(500, $user->fresh()->coins);
    }

    public function test_coins_only_series_is_not_included_in_vip(): void
    {
        $this->drama->update(['access_mode' => 'coins_only']);
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'monthly')->firstOrFail();
        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'mpesa', 'phone' => '+255700000001'])->assertCreated();

        $this->withToken($token)->getJson('/api/v1/episodes/'.$this->episode(5)->id.'/play')->assertStatus(402);
    }

    public function test_coin_ledger_records_purchase_bonus_and_unlock(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('name', 'Coins 550')->firstOrFail();

        $ref = $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'mpesa', 'phone' => '+255700000002'])
            ->assertCreated()->json('data.payment.reference');
        $this->withToken($token)->postJson('/api/v1/episodes/'.$this->episode(6)->id.'/unlock', ['method' => 'coins'])->assertOk();

        $this->withToken($token)->getJson('/api/v1/me/coins')->assertOk()
            ->assertJsonPath('meta.balance', 520)
            ->assertJsonPath('data.0.type', 'unlock')->assertJsonPath('data.0.amount', -30)->assertJsonPath('data.0.balance_after', 520)
            ->assertJsonPath('data.1.type', 'bonus')->assertJsonPath('data.2.type', 'purchase');

        $this->withToken($token)->getJson("/api/v1/me/payments/{$ref}/receipt")->assertOk()
            ->assertJsonPath('data.item.delivered', 'Coins 550')
            ->assertJsonPath('data.amount', 5000);
        $this->assertStringStartsWith('RCT-', Payment::where('reference', $ref)->value('receipt_number'));
    }

    public function test_checkout_is_idempotent(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('name', 'Coins 100')->firstOrFail();
        $body = ['plan_id' => $plan->id, 'payment_method' => 'mpesa', 'phone' => '+255700000003'];

        $first = $this->withToken($token)->withHeader('Idempotency-Key', 'key-12345678')->postJson('/api/v1/checkout', $body)->assertCreated()->json('data.payment.reference');
        $second = $this->withToken($token)->withHeader('Idempotency-Key', 'key-12345678')->postJson('/api/v1/checkout', $body)->assertOk()->json('data.payment.reference');

        $this->assertSame($first, $second);
        $this->assertSame(1, Payment::count());
        $this->assertSame(100, $user->fresh()->coins);
    }

    public function test_full_refund_reverses_coins_and_vip(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $coinsRef = $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => Plan::where('name', 'Coins 100')->value('id'), 'payment_method' => 'mpesa', 'phone' => '+255700000004'])->json('data.payment.reference');
        $vipRef = $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => Plan::where('type', 'monthly')->value('id'), 'payment_method' => 'mpesa', 'phone' => '+255700000004'])->json('data.payment.reference');
        $this->assertNotNull($user->activeTimeSubscription());

        $admin = $this->owner();
        $coinsPayment = Payment::where('reference', $coinsRef)->first();
        $this->withToken($admin)->postJson("/api/v1/admin/payments/{$coinsPayment->id}/refund", ['amount' => 400, 'reason' => 'Mteja aliomba'])
            ->assertOk()->assertJsonPath('data.payment.refunded_amount', 400)->assertJsonPath('data.payment.status', 'success');
        $this->withToken($admin)->postJson("/api/v1/admin/payments/{$coinsPayment->id}/refund", ['reason' => 'Salio'])
            ->assertOk()->assertJsonPath('data.payment.status', 'refunded');
        $this->assertSame(0, $user->fresh()->coins);

        $vipPayment = Payment::where('reference', $vipRef)->first();
        $this->withToken($admin)->postJson("/api/v1/admin/payments/{$vipPayment->id}/refund", ['reason' => 'Hitilafu'])->assertOk();
        $this->assertNull($user->fresh()->activeTimeSubscription());

        $this->withToken($admin)->getJson('/api/v1/admin/analytics?days=7')->assertOk()
            ->assertJsonPath('data.revenue.gross', 11000)
            ->assertJsonPath('data.revenue.refunds', 11000)
            ->assertJsonPath('data.revenue.net', 0);
        $this->assertDatabaseHas('audit_logs', ['action' => 'payment.refund', 'subject_id' => $vipPayment->id]);
    }

    public function test_player_events_feed_watch_time_completion_and_active_users(): void
    {
        $ep = $this->episode(1);
        $play = $this->withHeader('X-Device-Id', 'device-abc-123')->getJson("/api/v1/episodes/{$ep->id}/play")->assertOk()
            ->assertJsonPath('data.resume_seconds', 0)
            ->assertJsonPath('data.sources.0.quality', 'auto');
        $session = $play->json('data.session_id');

        $this->withHeader('X-Device-Id', 'device-abc-123')->postJson('/api/v1/events', ['events' => [
            ['session_id' => $session, 'episode_id' => $ep->id, 'type' => 'start', 'position_seconds' => 0, 'duration_seconds' => 90],
            ['session_id' => $session, 'episode_id' => $ep->id, 'type' => 'heartbeat', 'position_seconds' => 45, 'watched_seconds' => 45],
            ['session_id' => $session, 'episode_id' => $ep->id, 'type' => 'heartbeat', 'position_seconds' => 89, 'watched_seconds' => 9999],
        ]])->assertOk()->assertJsonPath('data.accepted', 3);

        $this->assertDatabaseHas('watch_sessions', ['session_key' => $session, 'watch_seconds' => 165, 'completed' => true]);

        $admin = $this->owner();
        $this->withToken($admin)->getJson('/api/v1/admin/analytics?days=7')->assertOk()
            ->assertJsonPath('data.audience.watch_seconds', 165)
            ->assertJsonPath('data.audience.unique_viewers', 1)
            ->assertJsonPath('data.audience.completion_rate', 1)
            ->assertJsonPath('data.active_users.dau', 1)
            ->assertJsonStructure(['data' => ['revenue' => ['gross', 'refunds', 'fees', 'net', 'streaming_cost', 'net_after_costs'],
                'coins' => ['purchased', 'spent'], 'payments' => ['attempts', 'success', 'failed', 'success_rate', 'by_method'], 'series']]);
        $this->withToken($admin)->getJson("/api/v1/admin/analytics/dramas/{$this->drama->id}?days=7")->assertOk()
            ->assertJsonPath('data.episodes.0.completion_rate', 1)
            ->assertJsonCount(10, 'data.drop_off');
    }

    public function test_resume_and_continue_watching(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $ep = $this->episode(2);
        $this->withToken($token)->getJson("/api/v1/episodes/{$ep->id}/play")->assertOk();
        $this->withToken($token)->postJson("/api/v1/episodes/{$ep->id}/progress", ['progress_seconds' => 40])->assertOk();

        $this->withToken($token)->getJson("/api/v1/episodes/{$ep->id}/play")->assertJsonPath('data.resume_seconds', 40);
        $home = $this->withToken($token)->getJson('/api/v1/home')->assertOk();
        $this->assertSame('continue_watching', $home->json('data.sections.0.key'));
        $this->assertSame(2, $home->json('data.sections.0.dramas.0.resume.episode_number'));
        $this->assertSame('Endelea kutazama', $home->json('data.sections.0.title'));
    }

    public function test_hls_playlists_are_served_with_signed_segment_urls(): void
    {
        Storage::fake('videos');
        Storage::disk('videos')->put('hls/1/master.m3u8', "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000\n480p/index.m3u8\n");
        Storage::disk('videos')->put('hls/1/480p/index.m3u8', "#EXTM3U\n#EXTINF:6.0,\nseg_0000.ts\n#EXT-X-ENDLIST\n");
        Storage::disk('videos')->put('hls/1/480p/seg_0000.ts', 'x');
        $ep = $this->episode(1);
        $ep->forceFill(['video_url' => 'private:episodes/x.mp4', 'hls_path' => 'hls/1/master.m3u8', 'renditions' => ['480p'], 'video_status' => 'ready'])->save();

        $play = $this->getJson("/api/v1/episodes/{$ep->id}/play")->assertOk()
            ->assertJsonPath('data.sources.0.type', 'hls')->assertJsonPath('data.sources.1.quality', '480p');
        $master = $this->get($play->json('data.video_url'))->assertOk()->getContent();
        $this->assertMatchesRegularExpression('#/api/v1/media/videos/hls/1/480p/index\.m3u8\?expires=\d+&signature=#', $master);

        preg_match('#(http\S+480p/index\.m3u8\S+)#', $master, $m);
        $variant = $this->get($m[1])->assertOk()->getContent();
        $this->assertStringContainsString('seg_0000.ts?expires=', $variant);

        $this->get('/api/v1/media/videos/hls/1/master.m3u8')->assertForbidden();
    }

    public function test_unapproved_episode_is_hidden_from_viewers(): void
    {
        $ep = Episode::create(['drama_id' => $this->drama->id, 'number' => 11, 'title' => 'Episode 11', 'video_url' => 'https://videos.example.com/11.mp4']);
        $this->getJson("/api/v1/episodes/{$ep->id}/play")->assertNotFound();
        $this->getJson("/api/v1/dramas/{$this->drama->slug}")->assertJsonCount(10, 'data.episodes');
    }
}
