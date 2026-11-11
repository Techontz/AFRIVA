<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;

class CatalogCacheTest extends ApiTestCase
{
    public function test_index_route_never_touches_the_database(): void
    {
        $queries = 0;
        DB::listen(function () use (&$queries) {
            $queries++;
        });

        $this->getJson('/')->assertOk()->assertJsonPath('version', 'v1');
        $this->assertSame(0, $queries);
    }

    public function test_cached_home_is_served_without_queries_for_guests(): void
    {
        $this->getJson('/api/v1/home')->assertOk();

        $queries = 0;
        DB::listen(function () use (&$queries) {
            $queries++;
        });
        $this->getJson('/api/v1/home')->assertOk()->assertJsonPath('data.banners.0.id', $this->drama->id);
        $this->assertSame(0, $queries);
    }

    public function test_studio_edit_invalidates_cached_drama_page(): void
    {
        $slug = $this->drama->slug;
        $this->getJson("/api/v1/dramas/{$slug}")->assertOk()->assertJsonPath('data.title', "The Chief's Hidden Heir");

        $token = $this->postJson('/api/v1/auth/login', ['login' => 'kilima-studios@afriva.com', 'password' => 'password'])->json('data.token');
        $this->withToken($token)->putJson("/api/v1/studio/dramas/{$this->drama->id}", ['title' => 'Renamed Drama'])->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken('')->getJson("/api/v1/dramas/{$slug}")->assertOk()->assertJsonPath('data.title', 'Renamed Drama');
    }

    public function test_cached_pages_stay_personalised(): void
    {
        $user = $this->viewer();
        $token = $this->tokenFor($user);
        $ep = $this->episode(5);

        // Warm the caches as a guest.
        $this->getJson('/api/v1/home')->assertOk()->assertJsonPath('data.banners.0.is_favorite', false);
        $this->getJson("/api/v1/dramas/{$this->drama->slug}")->assertOk();

        $this->withToken($token)->postJson("/api/v1/me/favorites/{$this->drama->id}")->assertOk();
        $user->update(['coins' => 100]);
        $this->withToken($token)->postJson("/api/v1/episodes/{$ep->id}/unlock", ['method' => 'coins'])->assertOk();

        $this->withToken($token)->getJson('/api/v1/home')->assertOk()->assertJsonPath('data.banners.0.is_favorite', true);
        $episodes = collect($this->withToken($token)->getJson("/api/v1/dramas/{$this->drama->slug}")->assertOk()->json('data.episodes'))->keyBy('number');
        $this->assertTrue($episodes[5]['is_unlocked']);
        $this->assertFalse($episodes[6]['is_unlocked']);

        // Guests still see their own (non personalised) view.
        $this->app['auth']->forgetGuards();
        $this->withToken('')->getJson('/api/v1/home')->assertOk()->assertJsonPath('data.banners.0.is_favorite', false);
    }
}
