<?php

namespace Tests\Feature;

use App\Models\Episode;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class VideoDeliveryTest extends ApiTestCase
{
    protected function studioToken(): string
    {
        return $this->postJson('/api/v1/auth/login', ['login' => 'kilima-studios@afriva.com', 'password' => 'password'])->json('data.token');
    }

    /** Uploads a video as episode 11 (locked: free_episodes = 3) and returns it. */
    protected function uploadEpisode(): Episode
    {
        $this->withToken($this->studioToken())->post("/api/v1/studio/dramas/{$this->drama->id}/episodes", [
            'title' => 'Uploaded', 'video' => UploadedFile::fake()->create('ep.mp4', 200, 'video/mp4'),
        ], ['Accept' => 'application/json'])->assertCreated();
        $this->app['auth']->forgetGuards();

        return Episode::where('drama_id', $this->drama->id)->where('number', 11)->firstOrFail();
    }

    public function test_uploaded_video_is_private_and_served_by_signed_url(): void
    {
        Storage::fake('videos');
        Storage::fake('public');
        $episode = $this->uploadEpisode();

        $this->assertStringStartsWith('private:episodes/', $episode->video_url);
        $path = substr($episode->video_url, strlen('private:'));
        Storage::disk('videos')->assertExists($path);
        Storage::disk('public')->assertMissing($path);

        // Locked for a viewer without access: no URL is handed out.
        $this->getJson("/api/v1/episodes/{$episode->id}/play")->assertStatus(402)->assertJsonMissingPath('data.video_url');

        // With access, the play endpoint returns a signed media URL that streams the file.
        $episode->update(['is_free' => true]);
        $url = $this->getJson("/api/v1/episodes/{$episode->id}/play")->assertOk()->json('data.video_url');
        $this->assertStringContainsString('/api/v1/media/videos/'.$path, $url);
        $this->assertStringContainsString('signature=', $url);

        $this->get($url)->assertOk();
        $this->getJson(preg_replace('/signature=[0-9a-f]+/', 'signature=deadbeef', $url))->assertForbidden();
        $this->getJson('/api/v1/media/videos/'.$path)->assertForbidden();

        $this->travel(config('media.video_url_ttl') + 1)->minutes();
        $this->getJson($url)->assertForbidden();
    }

    public function test_x_accel_mode_hands_the_file_to_nginx(): void
    {
        Storage::fake('videos');
        Storage::fake('public');
        $episode = $this->uploadEpisode();
        $episode->update(['is_free' => true]);
        config(['media.video_delivery' => 'x-accel']);

        $url = $this->getJson("/api/v1/episodes/{$episode->id}/play")->json('data.video_url');
        $path = substr($episode->video_url, strlen('private:'));

        $this->get($url)->assertOk()->assertHeader('X-Accel-Redirect', '/_protected_videos/'.$path);
    }

    public function test_resaving_with_the_signed_url_keeps_the_private_path(): void
    {
        Storage::fake('videos');
        Storage::fake('public');
        $episode = $this->uploadEpisode();
        $stored = $episode->video_url;
        $token = $this->studioToken();

        $signed = $this->withToken($token)->getJson("/api/v1/studio/dramas/{$this->drama->id}")->json('data.episodes.10.video_url');
        $this->assertStringContainsString('signature=', $signed);

        $this->withToken($token)->putJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$episode->id}", [
            'title' => 'Renamed', 'video_url' => $signed,
        ])->assertOk();
        $this->assertSame($stored, $episode->fresh()->video_url);

        // A hand-written private path pointing elsewhere is ignored.
        $this->withToken($token)->putJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$episode->id}", [
            'video_url' => 'private:episodes/someone-elses.mp4',
        ])->assertOk();
        $this->assertSame($stored, $episode->fresh()->video_url);

        // External URLs still work as before.
        $this->withToken($token)->putJson("/api/v1/studio/dramas/{$this->drama->id}/episodes/{$episode->id}", [
            'video_url' => 'https://cdn.example.com/ep.mp4',
        ])->assertOk();
        $this->assertSame('https://cdn.example.com/ep.mp4', $episode->fresh()->video_url);
    }
}
