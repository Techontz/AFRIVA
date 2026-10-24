<?php

namespace Tests\Feature;

class CatalogTest extends ApiTestCase
{
    public function test_home_shape(): void
    {
        $res = $this->getJson('/api/v1/home')->assertOk();

        $res->assertJsonStructure(['data' => [
            'banners' => [['id', 'slug', 'title', 'synopsis', 'poster_url', 'backdrop_url', 'total_episodes', 'free_episodes',
                'coins_per_episode', 'badge', 'views', 'categories' => [['id', 'name', 'slug']], 'tags', 'company' => ['id', 'name', 'slug'], 'is_favorite']],
            'sections' => [['key', 'title', 'layout', 'dramas']],
        ]]);
        $layouts = collect($res->json('data.sections'))->pluck('layout')->unique()->all();
        $this->assertContains('ranking', $layouts);
        $this->assertContains('row', $layouts);
    }

    public function test_drama_detail_with_episodes_and_related(): void
    {
        $res = $this->getJson('/api/v1/dramas/'.$this->drama->slug)->assertOk();

        $res->assertJsonPath('data.slug', $this->drama->slug)
            ->assertJsonPath('data.total_episodes', 10)
            ->assertJsonCount(10, 'data.episodes')
            ->assertJsonStructure(['data' => ['episodes' => [['id', 'number', 'title', 'duration_seconds', 'thumbnail_url', 'is_free', 'is_unlocked']], 'related']])
            ->assertJsonPath('data.episodes.0.is_free', true)
            ->assertJsonPath('data.episodes.3.is_free', false)
            ->assertJsonPath('data.episodes.3.is_unlocked', false)
            ->assertJsonMissingPath('data.episodes.0.video_url');
    }

    public function test_unknown_drama_404_shape(): void
    {
        $this->getJson('/api/v1/dramas/nope')->assertNotFound()->assertJsonPath('code', 'not_found');
    }

    public function test_dramas_list_paginated(): void
    {
        $this->getJson('/api/v1/dramas?category=romance&sort=newest&per_page=5')
            ->assertOk()
            ->assertJsonStructure(['data', 'meta' => ['current_page', 'last_page', 'total']])
            ->assertJsonPath('meta.total', 1);
    }

    public function test_plans_and_payment_methods(): void
    {
        $this->getJson('/api/v1/plans')->assertOk()->assertJsonCount(7, 'data')
            ->assertJsonStructure(['data' => [['id', 'name', 'type', 'price', 'currency', 'duration_days', 'episode_quota', 'coins', 'bonus_coins', 'features', 'is_popular']]]);
        $this->getJson('/api/v1/payment-methods')->assertOk()->assertJsonCount(10, 'data')
            ->assertJsonPath('data.0.code', 'mpesa')
            ->assertJsonPath('data.0.is_integrated', false);
    }

    public function test_rankings_and_feed(): void
    {
        $this->getJson('/api/v1/dramas/rankings?type=popular')->assertOk()->assertJsonPath('data.0.rank', 1);
        $this->getJson('/api/v1/feed')->assertOk()
            ->assertJsonStructure(['data' => [['drama' => ['id', 'slug'], 'episode' => ['id', 'number', 'video_url']]]])
            ->assertJsonPath('data.0.episode.number', 1);
    }
}
