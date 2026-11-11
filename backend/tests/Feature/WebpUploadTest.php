<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\WebpImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class WebpUploadTest extends ApiTestCase
{
    protected function studioToken(): string
    {
        return $this->tokenFor(User::where('email', 'kilima-studios@afriva.com')->firstOrFail());
    }

    /** @return array{0:string,1:string} [stored path, mime] */
    protected function uploadPoster(UploadedFile $file): array
    {
        Storage::fake('public');
        $url = $this->withToken($this->studioToken())->post('/api/v1/studio/dramas', ['title' => 'Webp Test', 'poster' => $file], ['Accept' => 'application/json'])
            ->assertCreated()->json('data.poster_url');
        $path = ltrim((string) preg_replace('#^.*/storage/#', '', (string) parse_url($url, PHP_URL_PATH)), '/');
        Storage::disk('public')->assertExists($path);

        return [$path, Storage::disk('public')->mimeType($path)];
    }

    public function test_png_and_jpeg_posters_are_stored_as_downscaled_webp(): void
    {
        if (! WebpImage::supported()) {
            $this->markTestSkipped('GD on this machine has no WebP support.');
        }

        [$path, $mime] = $this->uploadPoster(UploadedFile::fake()->image('poster.png', 1080, 1920));
        $this->assertStringEndsWith('.webp', $path);
        $this->assertSame('image/webp', $mime);
        [$w, $h] = getimagesizefromstring(Storage::disk('public')->get($path));
        $this->assertSame([720, 1280], [$w, $h]);

        [$path, $mime] = $this->uploadPoster(UploadedFile::fake()->image('poster.jpg', 600, 800));
        $this->assertStringEndsWith('.webp', $path);
        $this->assertSame('image/webp', $mime);
        $this->assertSame([600, 800], array_slice(getimagesizefromstring(Storage::disk('public')->get($path)), 0, 2)); // never upscaled
    }

    public function test_logos_fit_in_512_square(): void
    {
        if (! WebpImage::supported()) {
            $this->markTestSkipped('GD on this machine has no WebP support.');
        }
        Storage::fake('public');
        $url = $this->withToken($this->studioToken())->post('/api/v1/studio/profile', ['_method' => 'PUT', 'logo' => UploadedFile::fake()->image('logo.png', 2000, 1000)], ['Accept' => 'application/json'])
            ->assertOk()->json('data.company.logo_url');
        $path = ltrim((string) preg_replace('#^.*/storage/#', '', (string) parse_url($url, PHP_URL_PATH)), '/');
        $this->assertStringEndsWith('.webp', $path);
        $this->assertSame([512, 256], array_slice(getimagesizefromstring(Storage::disk('public')->get($path)), 0, 2));
    }
}
