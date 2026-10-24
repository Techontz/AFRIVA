<?php

namespace Tests\Feature;

use App\Models\Plan;

class EpisodeAccessTest extends ApiTestCase
{
    public function test_free_episode_plays_for_guest_and_records_view(): void
    {
        $ep = $this->episode(1);

        $this->getJson("/api/v1/episodes/{$ep->id}/play")
            ->assertOk()
            ->assertJsonPath('data.video_url', 'https://videos.example.com/1.mp4')
            ->assertJsonPath('data.episode.number', 1)
            ->assertJsonPath('data.next_episode_id', $this->episode(2)->id)
            ->assertJsonPath('data.prev_episode_id', null);

        $this->assertDatabaseHas('episode_views', ['episode_id' => $ep->id, 'company_id' => $this->company->id]);
        $this->assertSame(1, $ep->fresh()->views);
        $this->assertSame(1001, $this->drama->fresh()->views);
    }

    public function test_locked_episode_returns_402_with_unlock_info(): void
    {
        $user = $this->viewer(coins: 10);
        $ep = $this->episode(5);

        $this->withToken($this->tokenFor($user))->getJson("/api/v1/episodes/{$ep->id}/play")
            ->assertStatus(402)
            ->assertJsonPath('code', 'episode_locked')
            ->assertJsonPath('unlock.coins_required', 30)
            ->assertJsonPath('unlock.user_coins', 10)
            ->assertJsonPath('unlock.can_use_pack', false)
            ->assertJsonStructure(['message', 'code', 'unlock' => ['coins_required', 'user_coins', 'can_use_pack']]);

        $this->getJson("/api/v1/episodes/{$ep->id}/play")->assertStatus(402)->assertJsonPath('code', 'episode_locked');
    }

    public function test_unlock_with_coins_deducts_and_records_earnings(): void
    {
        $user = $this->viewer(coins: 200);
        $token = $this->tokenFor($user);
        $ep = $this->episode(6);

        $this->withToken($token)->postJson("/api/v1/episodes/{$ep->id}/unlock", ['method' => 'coins'])
            ->assertOk()
            ->assertJsonPath('data.unlocked', true)
            ->assertJsonPath('data.user_coins', 170)
            ->assertJsonPath('data.episode.is_unlocked', true);

        $this->assertSame(170, $user->fresh()->coins);
        $this->assertDatabaseHas('episode_unlocks', ['user_id' => $user->id, 'episode_id' => $ep->id, 'method' => 'coins', 'coins_spent' => 30]);
        // 30 coins × 10 TZS × 70% = 210
        $this->assertDatabaseHas('company_earnings', ['company_id' => $this->company->id, 'source' => 'coins', 'amount' => 210]);

        $this->withToken($token)->getJson("/api/v1/episodes/{$ep->id}/play")->assertOk()
            ->assertJsonPath('data.video_url', 'https://videos.example.com/6.mp4');

        // Unlocking again does not charge twice.
        $this->withToken($token)->postJson("/api/v1/episodes/{$ep->id}/unlock", ['method' => 'coins'])
            ->assertOk()->assertJsonPath('data.already_unlocked', true)->assertJsonPath('data.user_coins', 170);
    }

    public function test_unlock_with_insufficient_coins(): void
    {
        $user = $this->viewer(coins: 5);
        $this->withToken($this->tokenFor($user))->postJson('/api/v1/episodes/'.$this->episode(7)->id.'/unlock', ['method' => 'coins'])
            ->assertStatus(402)->assertJsonPath('code', 'insufficient_coins');
        $this->assertSame(5, $user->fresh()->coins);
    }

    public function test_episode_pack_checkout_and_unlock_decrements_quota(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $plan = Plan::where('type', 'episodes')->where('episode_quota', 6)->firstOrFail();

        $this->withToken($token)->postJson('/api/v1/checkout', ['plan_id' => $plan->id, 'payment_method' => 'mpesa', 'phone' => '+255700000000'])
            ->assertCreated()->assertJsonPath('data.payment.status', 'success');

        $this->withToken($token)->getJson('/api/v1/episodes/'.$this->episode(4)->id.'/play')
            ->assertStatus(402)->assertJsonPath('unlock.can_use_pack', true);

        $this->withToken($token)->postJson('/api/v1/episodes/'.$this->episode(4)->id.'/unlock', ['method' => 'episode_pack'])
            ->assertOk()->assertJsonPath('data.episodes_remaining', 5);

        $this->assertDatabaseHas('subscriptions', ['user_id' => $user->id, 'type' => 'episodes', 'episodes_remaining' => 5]);
        // 10000 / 6 × 70% = 1167
        $this->assertDatabaseHas('company_earnings', ['source' => 'episode_pack', 'amount' => 1167]);
    }

    public function test_progress_saves_history(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $this->withToken($token)->postJson('/api/v1/episodes/'.$this->episode(2)->id.'/progress', ['progress_seconds' => 42])->assertOk();
        $this->withToken($token)->getJson('/api/v1/me/history')->assertOk()
            ->assertJsonPath('data.0.progress_seconds', 42)
            ->assertJsonPath('data.0.episode.number', 2);
    }
}
