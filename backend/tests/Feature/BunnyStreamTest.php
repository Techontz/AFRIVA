<?php

namespace Tests\Feature;

use App\Models\Episode;
use App\Models\User;
use App\Services\BunnyStream;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Http;

class BunnyStreamTest extends ApiTestCase
{
    protected const LIBRARY = '794966';

    protected const API_KEY = 'secret-api-key-123';

    protected const CDN = 'vz-test-123.b-cdn.net';

    protected const GUID = '11111111-2222-3333-4444-555555555555';

    protected const OLD_GUID = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.bunny' => [
            'library_id' => self::LIBRARY,
            'api_key' => self::API_KEY,
            'cdn_hostname' => self::CDN,
            'token_auth_key' => '',
            'token_ttl' => 14400,
            'webhook_secret' => '',
            'enabled' => true,
        ]]);
    }

    protected function studioToken(string $slug = 'kilima-studios'): string
    {
        return $this->postJson('/api/v1/auth/login', ['login' => "$slug@afriva.com", 'password' => 'password'])->json('data.token');
    }

    protected function adminToken(): string
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'admin@afriva.com', 'password' => 'password', 'role' => 'super_admin']);

        return $this->tokenFor($admin);
    }

    /** Fake Bunny: create returns GUID, get returns $video, delete succeeds. */
    protected function fakeBunny(array $video = []): void
    {
        $base = 'https://video.bunnycdn.com/library/'.self::LIBRARY.'/videos';
        Http::fake(function (HttpRequest $request) use ($base, $video) {
            if ($request->method() === 'POST' && $request->url() === $base) {
                return Http::response(['guid' => self::GUID, 'videoLibraryId' => (int) self::LIBRARY, 'title' => $request['title'], 'status' => 0]);
            }
            if ($request->method() === 'GET' && str_starts_with($request->url(), $base.'/')) {
                $guid = substr($request->url(), strlen($base) + 1);

                return isset($video[$guid]) ? Http::response($video[$guid]) : Http::response(['success' => false], 404);
            }
            if ($request->method() === 'DELETE') {
                return Http::response(['success' => true, 'statusCode' => 200]);
            }

            return Http::response([], 500);
        });
    }

    protected function videoModel(string $guid, int $status, array $extra = []): array
    {
        return array_merge([
            'guid' => $guid, 'videoLibraryId' => (int) self::LIBRARY, 'title' => 'x', 'status' => $status,
            'length' => 0, 'availableResolutions' => null, 'thumbnailFileName' => 'thumbnail.jpg', 'encodeProgress' => 0,
        ], $extra);
    }

    protected function webhook(string $guid, int $status, ?string $library = null)
    {
        return $this->postJson('/api/v1/webhooks/bunny', [
            'VideoLibraryId' => (int) ($library ?? self::LIBRARY), 'VideoGuid' => $guid, 'Status' => $status,
            'IsLiveStreamWebhook' => false, 'EventId' => 'evt-1', 'Timestamp' => now()->toIso8601String(),
        ]);
    }

    protected function processingEpisode(int $number = 4): Episode
    {
        $ep = $this->episode($number);
        $ep->forceFill(['bunny_video_id' => self::GUID, 'video_status' => 'processing', 'video_url' => null,
            'thumbnail_url' => $this->drama->poster_url])->save();

        return $ep;
    }

    // ---- Upload credentials ------------------------------------------------

    public function test_studio_gets_upload_credentials_with_correct_signature_and_no_api_key(): void
    {
        $this->fakeBunny();
        $ep = $this->episode(2);
        $res = $this->withToken($this->studioToken())
            ->postJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}/video-upload")
            ->assertOk()
            ->assertJsonStructure(['data' => ['video_id', 'library_id', 'tus_endpoint', 'signature', 'expires', 'title']]);

        $data = $res->json('data');
        $this->assertSame(self::GUID, $data['video_id']);
        $this->assertSame(self::LIBRARY, $data['library_id']);
        $this->assertSame('https://video.bunnycdn.com/tusupload', $data['tus_endpoint']);
        $this->assertSame("The Chief's Hidden Heir - Ep 2", $data['title']);
        $this->assertEqualsWithDelta(time() + 6 * 3600, $data['expires'], 5);
        $this->assertSame(hash('sha256', self::LIBRARY.self::API_KEY.$data['expires'].self::GUID), $data['signature']);
        $this->assertStringNotContainsString(self::API_KEY, $res->getContent());

        $ep->refresh();
        $this->assertSame(self::GUID, $ep->bunny_video_id);
        $this->assertSame('uploading', $ep->video_status);

        Http::assertSent(fn (HttpRequest $r) => $r->method() === 'POST'
            && $r->url() === 'https://video.bunnycdn.com/library/'.self::LIBRARY.'/videos'
            && $r->hasHeader('AccessKey', self::API_KEY)
            && $r['title'] === "The Chief's Hidden Heir - Ep 2");

        // Complete: processing, idempotent, resource exposes the new fields.
        $url = "/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}/video-upload/complete";
        $token = $this->studioToken();
        $this->withToken($token)->postJson($url, ['video_id' => self::GUID])->assertOk()
            ->assertJsonPath('data.video_status', 'processing')
            ->assertJsonPath('data.bunny_video_id', self::GUID);
        $this->withToken($token)->postJson($url)->assertOk()->assertJsonPath('data.video_status', 'processing');
        $this->withToken($token)->postJson($url, ['video_id' => self::OLD_GUID])->assertStatus(409)->assertJsonPath('code', 'video_upload_mismatch');
    }

    public function test_upload_returns_503_when_bunny_not_configured(): void
    {
        Http::fake();
        config(['services.bunny.api_key' => '']);
        $ep = $this->episode(1);
        $this->withToken($this->studioToken())
            ->postJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}/video-upload")
            ->assertStatus(503)->assertJsonPath('code', 'video_storage_not_configured');
        Http::assertNothingSent();

        $this->withHeader('Accept-Language', 'sw')->withToken($this->studioToken())
            ->postJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}/video-upload")
            ->assertStatus(503)->assertJsonPath('message', __('api.video_storage_not_configured', [], 'sw'));
    }

    public function test_studio_cannot_upload_to_another_companys_episode_but_admin_can(): void
    {
        $this->fakeBunny();
        $other = $this->makeCompany('Lagos Reel House', 'lagos-reel-house');
        $otherDrama = $this->makeDrama($other, 'Divorced, Then Crowned', 2);
        $otherEp = $otherDrama->episodes()->first();
        $token = $this->studioToken();

        $this->withToken($token)->postJson("/api/v1/studio/dramas/{$otherDrama->id}/episodes/{$otherEp->id}/video-upload")->assertNotFound();
        $this->withToken($token)->postJson("/api/v1/studio/dramas/{$otherDrama->id}/episodes/{$otherEp->id}/video-upload/complete")->assertNotFound();
        // Own drama id with someone else's episode id.
        $this->withToken($token)->postJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$otherEp->id}/video-upload")->assertNotFound();
        Http::assertNothingSent();
        $this->assertNull($otherEp->fresh()->bunny_video_id);

        $this->app['auth']->forgetGuards();
        $this->withToken($this->adminToken())
            ->postJson("/api/v1/admin/dramas/{$otherDrama->id}/episodes/{$otherEp->id}/video-upload")
            ->assertOk()->assertJsonPath('data.video_id', self::GUID);
        $this->assertSame('uploading', $otherEp->fresh()->video_status);
    }

    public function test_reupload_keeps_playing_video_until_new_one_is_ready(): void
    {
        $ep = $this->episode(1);
        $ep->forceFill(['bunny_video_id' => self::OLD_GUID, 'video_status' => 'ready',
            'video_url' => 'https://'.self::CDN.'/'.self::OLD_GUID.'/playlist.m3u8'])->save();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 4, ['length' => 125, 'availableResolutions' => '360p,720p'])]);

        $this->withToken($this->studioToken())
            ->postJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}/video-upload")->assertOk();
        Http::assertNotSent(fn (HttpRequest $r) => $r->method() === 'DELETE');
        // Old video still playable while the new one uploads.
        $this->getJson("/api/v1/episodes/{$ep->id}/play")->assertOk()
            ->assertJsonPath('data.video_url', 'https://'.self::CDN.'/'.self::OLD_GUID.'/playlist.m3u8');

        $this->webhook(self::GUID, 3)->assertOk();
        $ep->refresh();
        $this->assertSame('ready', $ep->video_status);
        $this->assertSame('https://'.self::CDN.'/'.self::GUID.'/playlist.m3u8', $ep->video_url);
        Http::assertSent(fn (HttpRequest $r) => $r->method() === 'DELETE' && str_ends_with($r->url(), '/videos/'.self::OLD_GUID));
    }

    // ---- Webhook -------------------------------------------------------------

    public function test_webhook_marks_ready_using_get_video(): void
    {
        $ep = $this->processingEpisode();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 4, ['length' => 312, 'availableResolutions' => '240p,720p'])]);

        $this->webhook(self::GUID, 3)->assertOk()->assertJsonPath('data.received', true);

        $ep->refresh();
        $this->assertSame('ready', $ep->video_status);
        $this->assertSame(312, $ep->duration_seconds);
        $this->assertSame('https://'.self::CDN.'/'.self::GUID.'/playlist.m3u8', $ep->video_url);
        $this->assertSame('https://'.self::CDN.'/'.self::GUID.'/thumbnail.jpg', $ep->thumbnail_url);
        Http::assertSent(fn (HttpRequest $r) => $r->method() === 'GET' && $r->hasHeader('AccessKey', self::API_KEY)
            && $r->url() === 'https://video.bunnycdn.com/library/'.self::LIBRARY.'/videos/'.self::GUID);
    }

    public function test_webhook_keeps_existing_custom_thumbnail(): void
    {
        $ep = $this->processingEpisode();
        $ep->forceFill(['thumbnail_url' => 'https://example.com/custom.jpg'])->save();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 4, ['length' => 60])]);

        $this->webhook(self::GUID, 3)->assertOk();
        $this->assertSame('https://example.com/custom.jpg', $ep->fresh()->thumbnail_url);
    }

    public function test_webhook_resolution_finished_marks_ready_when_playable(): void
    {
        $ep = $this->processingEpisode();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 3, ['length' => 90, 'availableResolutions' => '240p'])]);

        $this->webhook(self::GUID, 4)->assertOk();
        $this->assertSame('ready', $ep->fresh()->video_status);
    }

    public function test_webhook_failed(): void
    {
        $ep = $this->processingEpisode();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 5)]);

        $this->webhook(self::GUID, 5)->assertOk();
        $this->assertSame('failed', $ep->fresh()->video_status);
        $this->assertNull($ep->fresh()->video_url);
    }

    public function test_webhook_spoof_is_ignored_when_bunny_says_still_processing(): void
    {
        $ep = $this->processingEpisode();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 3, ['encodeProgress' => 40])]);

        $this->webhook(self::GUID, 3)->assertOk();
        $ep->refresh();
        $this->assertSame('processing', $ep->video_status);
        $this->assertNull($ep->video_url);
    }

    public function test_webhook_unknown_library_or_video_is_ignored(): void
    {
        $ep = $this->processingEpisode();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 4)]);

        $this->webhook(self::GUID, 3, '999999')->assertOk();
        $this->webhook('99999999-9999-9999-9999-999999999999', 3)->assertOk();
        $this->postJson('/api/v1/webhooks/bunny', ['garbage' => true])->assertOk();

        Http::assertNothingSent();
        $this->assertSame('processing', $ep->fresh()->video_status);
    }

    public function test_webhook_signature_is_enforced_when_secret_configured(): void
    {
        config(['services.bunny.webhook_secret' => 'read-only-key']);
        $ep = $this->processingEpisode();
        $this->fakeBunny([self::GUID => $this->videoModel(self::GUID, 4, ['length' => 10])]);

        $this->webhook(self::GUID, 3)->assertOk();
        $this->assertSame('processing', $ep->fresh()->video_status);
        Http::assertNothingSent();

        $body = json_encode(['VideoLibraryId' => (int) self::LIBRARY, 'VideoGuid' => self::GUID, 'Status' => 3]);
        $this->call('POST', '/api/v1/webhooks/bunny', [], [], [], [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_BUNNYSTREAM_SIGNATURE_VERSION' => 'v1',
            'HTTP_X_BUNNYSTREAM_SIGNATURE_ALGORITHM' => 'hmac-sha256',
            'HTTP_X_BUNNYSTREAM_SIGNATURE' => hash_hmac('sha256', $body, 'read-only-key'),
        ], $body)->assertOk();
        $this->assertSame('ready', $ep->fresh()->video_status);
    }

    // ---- Playback ----------------------------------------------------------

    public function test_signed_hls_url_format(): void
    {
        config(['services.bunny.token_auth_key' => 'token-key-abc']);
        $bunny = app(BunnyStream::class);
        $expires = 1900000000;
        $url = $bunny->signDirectoryUrl('https://'.self::CDN.'/'.self::GUID.'/playlist.m3u8', '/'.self::GUID.'/', $expires);

        $path = '/'.self::GUID.'/';
        $expected = 'HS256-'.rtrim(strtr(base64_encode(hash_hmac('sha256', $path.$expires.'token_path='.$path, 'token-key-abc', true)), '+/', '-_'), '=');
        $this->assertSame(
            'https://'.self::CDN.'/bcdn_token='.$expected.'&token_path=%2F'.self::GUID.'%2F&expires='.$expires.'/'.self::GUID.'/playlist.m3u8',
            $url
        );
        $this->assertSame(self::GUID, $bunny->guidFromUrl($url));
        $this->assertSame('https://'.self::CDN.'/'.self::GUID.'/playlist.m3u8', $bunny->unsignUrl($url));
    }

    public function test_play_returns_signed_url_only_to_viewers_with_access(): void
    {
        config(['services.bunny.token_auth_key' => 'token-key-abc']);
        $raw = 'https://'.self::CDN.'/'.self::GUID.'/playlist.m3u8';
        foreach ([1, 5] as $n) {
            $this->episode($n)->forceFill(['bunny_video_id' => self::GUID, 'video_status' => 'ready', 'video_url' => $raw])->save();
        }

        $free = $this->getJson('/api/v1/episodes/'.$this->episode(1)->id.'/play')->assertOk();
        $url = $free->json('data.video_url');
        $this->assertMatchesRegularExpression('#^https://'.preg_quote(self::CDN).'/bcdn_token=HS256-[A-Za-z0-9_-]+&token_path=%2F'.self::GUID.'%2F&expires=(\d+)/'.self::GUID.'/playlist\.m3u8$#', $url);
        preg_match('#expires=(\d+)/#', $url, $m);
        $this->assertEqualsWithDelta(time() + 14400, (int) $m[1], 5);
        $this->assertSame($url, $free->json('data.episode.video_url'));

        // Locked episode: no URL at all.
        $locked = $this->getJson('/api/v1/episodes/'.$this->episode(5)->id.'/play')->assertStatus(402)->assertJsonPath('code', 'episode_locked');
        $this->assertStringNotContainsString(self::GUID, $locked->getContent());

        // Drama page lists episodes without any video URL.
        $page = $this->getJson('/api/v1/dramas/'.$this->drama->slug)->assertOk();
        $this->assertStringNotContainsString('playlist.m3u8', $page->getContent());

        // After unlocking, the unlock payload carries a signed URL.
        $viewer = $this->viewer(100);
        $this->withToken($this->tokenFor($viewer))->postJson('/api/v1/episodes/'.$this->episode(5)->id.'/unlock', ['method' => 'coins'])
            ->assertOk()->assertJsonPath('data.unlocked', true)
            ->assertJson(fn ($json) => $json->where('data.episode.video_url', fn ($v) => str_contains($v, '/bcdn_token=HS256-'))->etc());
    }

    public function test_unsigned_url_when_no_token_key_and_thumbnails_signed_when_key_set(): void
    {
        $raw = 'https://'.self::CDN.'/'.self::GUID.'/playlist.m3u8';
        $thumb = 'https://'.self::CDN.'/'.self::GUID.'/thumbnail.jpg';
        $this->episode(1)->forceFill(['bunny_video_id' => self::GUID, 'video_status' => 'ready', 'video_url' => $raw, 'thumbnail_url' => $thumb])->save();

        $this->getJson('/api/v1/episodes/'.$this->episode(1)->id.'/play')->assertOk()
            ->assertJsonPath('data.video_url', $raw)
            ->assertJsonPath('data.episode.thumbnail_url', $thumb);

        config(['services.bunny.token_auth_key' => 'token-key-abc']);
        $signed = $this->getJson('/api/v1/episodes/'.$this->episode(1)->id.'/play')->json('data.episode.thumbnail_url');
        $this->assertMatchesRegularExpression('#^'.preg_quote($thumb).'\?token=HS256-[A-Za-z0-9_-]+&expires=(\d+)$#', $signed);
        preg_match('#expires=(\d+)$#', $signed, $m);
        $this->assertSame(0, (int) $m[1] % (7 * 86400));
        $this->assertGreaterThanOrEqual(time() + 7 * 86400, (int) $m[1]);

        // Studio gets the raw values to edit plus a signed preview; echoing a signed URL back stores it raw.
        $token = $this->studioToken();
        $ep = $this->episode(1);
        $this->withToken($token)->getJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}")->assertOk()
            ->assertJsonPath('data.video_url', $raw)
            ->assertJsonPath('data.thumbnail_url', $thumb)
            ->assertJsonPath('data.thumbnail_preview_url', $signed)
            ->assertJsonPath('data.video_status', 'ready');
        $this->withToken($token)->putJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}", ['thumbnail_url' => $signed, 'title' => 'Renamed'])->assertOk();
        $this->assertSame($thumb, $ep->fresh()->thumbnail_url);
        $this->assertSame(self::GUID, $ep->fresh()->bunny_video_id);
    }

    public function test_episode_without_ready_video_is_coming_soon(): void
    {
        $ep = $this->processingEpisode(1);
        $this->getJson("/api/v1/episodes/{$ep->id}/play")->assertOk()
            ->assertJsonPath('data.video_url', null)
            ->assertJsonPath('data.episode.video_url', null);
        $this->assertSame(0, $ep->fresh()->views);
        $this->getJson('/api/v1/feed')->assertOk();
    }

    public function test_pasted_video_url_marks_ready_and_clears_bunny_video(): void
    {
        $ep = $this->processingEpisode(1);
        $this->fakeBunny();

        $this->withToken($this->studioToken())
            ->putJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}", ['video_url' => 'https://videos.example.com/new.mp4'])
            ->assertOk()
            ->assertJsonPath('data.video_status', 'ready')
            ->assertJsonPath('data.bunny_video_id', null)
            ->assertJsonPath('data.video_url', 'https://videos.example.com/new.mp4');
        Http::assertSent(fn (HttpRequest $r) => $r->method() === 'DELETE' && str_ends_with($r->url(), '/videos/'.self::GUID));
    }

    public function test_deleting_episode_deletes_bunny_video(): void
    {
        $ep = $this->processingEpisode(2);
        $this->fakeBunny();

        $this->withToken($this->studioToken())
            ->deleteJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}")->assertOk();
        Http::assertSent(fn (HttpRequest $r) => $r->method() === 'DELETE'
            && $r->url() === 'https://video.bunnycdn.com/library/'.self::LIBRARY.'/videos/'.self::GUID
            && $r->hasHeader('AccessKey', self::API_KEY));
    }

    public function test_deleting_episode_survives_bunny_failure(): void
    {
        $ep = $this->processingEpisode(2);
        Http::fake(['*' => Http::response(['message' => 'boom'], 500)]);

        $this->withToken($this->studioToken())
            ->deleteJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$ep->id}")->assertOk();
        $this->assertNull(Episode::find($ep->id));
    }

    // ---- bunny:sync --------------------------------------------------------

    public function test_sync_command_applies_bunny_state_to_stale_uploads(): void
    {
        $stale = $this->processingEpisode(3);
        Episode::whereKey($stale->id)->update(['updated_at' => now()->subMinutes(10)]);

        $failGuid = '22222222-3333-4444-5555-666666666666';
        $failing = $this->episode(4);
        $failing->forceFill(['bunny_video_id' => $failGuid, 'video_status' => 'uploading'])->save();
        Episode::whereKey($failing->id)->update(['updated_at' => now()->subMinutes(10)]);

        $freshGuid = '33333333-4444-5555-6666-777777777777';
        $fresh = $this->episode(5);
        $fresh->forceFill(['bunny_video_id' => $freshGuid, 'video_status' => 'processing'])->save();

        $this->fakeBunny([
            self::GUID => $this->videoModel(self::GUID, 4, ['length' => 200]),
            $failGuid => $this->videoModel($failGuid, 6),
            $freshGuid => $this->videoModel($freshGuid, 4, ['length' => 50]),
        ]);

        $this->artisan('bunny:sync')->assertSuccessful();

        $this->assertSame('ready', $stale->fresh()->video_status);
        $this->assertSame(200, $stale->fresh()->duration_seconds);
        $this->assertSame('failed', $failing->fresh()->video_status);
        // Updated less than 2 minutes ago: left alone.
        $this->assertSame('processing', $fresh->fresh()->video_status);
        Http::assertNotSent(fn (HttpRequest $r) => str_contains($r->url(), $freshGuid));
    }

    public function test_sync_command_is_noop_when_not_configured(): void
    {
        Http::fake();
        config(['services.bunny.library_id' => '']);
        $this->artisan('bunny:sync')->assertSuccessful();
        Http::assertNothingSent();
    }
}
