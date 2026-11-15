<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\StudioApplication;
use App\Models\User;
use App\Services\BunnyStream;
use App\Support\WebpImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class MediaStorageTest extends ApiTestCase
{
    protected function admin(): User
    {
        return User::create(['name' => 'Admin', 'email' => 'admin@afriva.com', 'password' => 'password', 'role' => 'super_admin']);
    }

    protected function studioToken(): string
    {
        return $this->tokenFor(User::where('email', 'kilima-studios@afriva.com')->firstOrFail());
    }

    public function test_defaults_keep_the_local_disks(): void
    {
        $this->assertSame('public', config('filesystems.media_disk'));
        $this->assertSame('local', config('filesystems.private_documents_disk'));
        $this->assertSame('local', StudioApplication::disk());
    }

    public function test_r2_disks_are_configured_for_cloudflare(): void
    {
        foreach (['r2_public', 'r2_private'] as $disk) {
            $this->assertSame('s3', config("filesystems.disks.$disk.driver"));
            $this->assertSame('auto', config("filesystems.disks.$disk.region"));
            $this->assertTrue(config("filesystems.disks.$disk.use_path_style_endpoint"));
            $this->assertFalse(config("filesystems.disks.$disk.retain_visibility"));
        }
        $this->assertArrayNotHasKey('url', config('filesystems.disks.r2_private'));
    }

    public function test_uploads_go_to_the_r2_public_disk_when_media_disk_selects_it(): void
    {
        config(['filesystems.media_disk' => 'r2_public']);
        Storage::fake('public');
        Storage::fake('r2_public', ['url' => 'https://media.afriva.co.tz']);

        $file = WebpImage::supported() ? UploadedFile::fake()->image('poster.png', 600, 800) : UploadedFile::fake()->create('poster.pdf', 10, 'application/pdf');
        $url = $this->withToken($this->studioToken())->post('/api/v1/studio/dramas', ['title' => 'R2 Poster', 'poster' => $file], ['Accept' => 'application/json'])
            ->assertCreated()->json('data.poster_url');

        $this->assertStringStartsWith('https://media.afriva.co.tz/posters/', $url);
        Storage::disk('r2_public')->assertExists(substr($url, strlen('https://media.afriva.co.tz/')));
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_r2_urls_are_not_rewritten_by_the_media_cdn_and_are_stored_as_is(): void
    {
        config(['services.bunny.media_cdn_url' => 'https://afrivamedia.b-cdn.net', 'app.url' => 'https://api.afriva.co.tz']);
        $bunny = app(BunnyStream::class);
        $r2 = 'https://media.afriva.co.tz/posters/a.webp';
        $this->assertSame($r2, $bunny->toMediaCdn($r2));
        $this->assertSame($r2, $bunny->unsignUrl($r2));
        // Local files still go through the pull zone.
        $this->assertSame('https://afrivamedia.b-cdn.net/storage/posters/a.webp', $bunny->toMediaCdn('https://api.afriva.co.tz/storage/posters/a.webp'));
    }

    protected function companyWithDocument(string $disk): Company
    {
        Storage::disk($disk)->put('id-documents/abc.pdf', '%PDF-1.4 test');
        $company = Company::create(['name' => 'Doc Co', 'slug' => 'doc-co', 'status' => 'pending']);
        StudioApplication::create([
            'company_id' => $company->id, 'full_name' => 'Asha Doc', 'id_type' => 'passport', 'phone' => '+255700000001',
            'guidelines_accepted_at' => now(), 'creator_share_percent' => 60, 'status' => 'pending',
            'id_document_path' => 'id-documents/abc.pdf',
        ]);

        return $company;
    }

    public function test_private_documents_on_r2_are_served_by_short_lived_signed_urls_to_admins_only(): void
    {
        config(['filesystems.private_documents_disk' => 'r2_private']);
        Storage::fake('r2_private');
        Storage::fake('local');
        $company = $this->companyWithDocument('r2_private');
        $url = "/api/v1/admin/companies/{$company->id}/id-document";

        $this->getJson($url)->assertStatus(401);
        $this->withToken($this->tokenFor($this->viewer()))->getJson($url)->assertStatus(403);
        $this->app['auth']->forgetGuards();

        $token = $this->tokenFor($this->admin());
        $this->travelTo(now()->startOfMinute());
        $redirect = $this->withToken($token)->get($url)->assertRedirect();
        $location = $redirect->headers->get('Location');
        $this->assertStringContainsString('id-documents/abc.pdf', $location);
        parse_str((string) parse_url($location, PHP_URL_QUERY), $q);
        $this->assertSame(now()->addMinutes(10)->getTimestamp(), (int) $q['expiration']);
        $this->assertStringContainsString('no-store', $redirect->headers->get('Cache-Control'));

        $this->withToken($token)->getJson($url.'?as=url')->assertOk()
            ->assertJsonPath('data.pdf', true)
            ->assertJsonPath('data.expires_at', now()->addMinutes(10)->toIso8601String());
    }

    public function test_private_documents_on_the_local_disk_are_still_streamed(): void
    {
        Storage::fake('local');
        $company = $this->companyWithDocument('local');

        $res = $this->withToken($this->tokenFor($this->admin()))->get("/api/v1/admin/companies/{$company->id}/id-document?as=url")->assertOk();
        $this->assertSame('%PDF-1.4 test', $res->streamedContent());
    }

    public function test_new_id_documents_are_stored_on_the_configured_private_disk(): void
    {
        config(['filesystems.private_documents_disk' => 'r2_private']);
        Storage::fake('r2_private');
        Storage::fake('local');
        $this->post('/api/v1/auth/studio-application', [
            'full_name' => 'Asha Mwinyi', 'studio_name' => 'Bongo Films', 'email' => 'asha@example.com', 'phone' => '+255712345678',
            'password' => 'password123', 'password_confirmation' => 'password123', 'id_type' => 'passport',
            'id_document' => UploadedFile::fake()->create('passport.pdf', 50, 'application/pdf'),
            'guidelines_accepted' => true, 'payout_method' => 'mobile_money', 'payout_provider' => 'mpesa',
            'payout_account_name' => 'Asha Mwinyi', 'payout_account_number' => '0712345678',
        ], ['Accept' => 'application/json'])->assertCreated();

        $path = StudioApplication::firstOrFail()->id_document_path;
        Storage::disk('r2_private')->assertExists($path);
        Storage::disk('local')->assertMissing($path);
    }
}
