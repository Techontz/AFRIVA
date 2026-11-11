<?php

namespace Tests\Feature;

use App\Models\Drama;
use App\Services\BunnyStream;
use Database\Seeders\ShowcaseSeeder;
use Illuminate\Support\Facades\Http;

class ShowcaseTest extends ApiTestCase
{
    protected const GUID = 'c648e701-fdb5-4c8c-b8a0-631d204f9fe9';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.bunny' => [
            'library_id' => '794966',
            'api_key' => 'secret',
            'cdn_hostname' => 'vz-test-123.b-cdn.net',
            'token_auth_key' => '',
            'token_ttl' => 14400,
            'webhook_secret' => '',
            'showcase_video' => self::GUID,
            'protected_videos' => [self::GUID],
            'enabled' => true,
        ]]);
    }

    public function test_showcase_seeds_published_dramas_playing_the_shared_video(): void
    {
        $this->seed(ShowcaseSeeder::class);

        $drama = Drama::where('slug', 'mirambo')->firstOrFail();
        $this->assertSame('published', $drama->status);
        $this->assertSame(70, $drama->episodes()->count());
        $this->assertSame('https://vz-test-123.b-cdn.net/'.self::GUID.'/playlist.m3u8', $drama->episodes()->first()->video_url);

        $sections = collect($this->getJson('/api/v1/home')->assertOk()->json('data.sections'));
        $this->assertNotEmpty($sections->firstWhere('key', 'trending')['dramas']);
        $historical = $sections->firstWhere('key', 'historical');
        $this->assertSame('historical', $historical['category']);
        $this->assertNotEmpty($historical['dramas']);
    }

    public function test_protected_videos_are_never_deleted_at_bunny(): void
    {
        Http::fake();

        $this->assertFalse(app(BunnyStream::class)->deleteVideo(self::GUID));
        Http::assertNothingSent();
    }

    public function test_public_files_are_served_through_the_media_cdn_when_configured(): void
    {
        config(['app.url' => 'https://api.example.test', 'services.bunny.media_cdn_url' => 'https://media.example-cdn.net']);
        $this->seed(ShowcaseSeeder::class);

        $drama = $this->getJson('/api/v1/dramas/mirambo')->assertOk()->json('data');
        $this->assertSame('https://media.example-cdn.net/showcase/mirambo.webp', $drama['poster_url']);
        $this->assertSame('https://api.example.test/showcase/mirambo.webp', Drama::where('slug', 'mirambo')->value('poster_url'));
        $this->assertSame('https://api.example.test/showcase/x.jpg', app(BunnyStream::class)->unsignUrl('https://media.example-cdn.net/showcase/x.jpg'));
    }
}
