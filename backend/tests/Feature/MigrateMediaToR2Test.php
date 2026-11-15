<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\StudioApplication;
use App\Models\User;
use Illuminate\Support\Facades\Storage;

class MigrateMediaToR2Test extends ApiTestCase
{
    protected const R2 = 'https://media.afriva.co.tz';

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.url' => 'https://api.afriva.co.tz', 'services.bunny.media_cdn_url' => 'https://afrivamedia.b-cdn.net', 'filesystems.disks.r2_public.url' => self::R2]);
        Storage::fake('public');
        Storage::fake('local');
        Storage::fake('r2_public', ['url' => self::R2]);
        Storage::fake('r2_private');

        Storage::disk('public')->put('posters/p1.webp', 'poster-bytes');
        Storage::disk('public')->put('backdrops/b1.webp', 'backdrop-bytes');
        Storage::disk('public')->put('logos/l1.webp', 'logo-bytes');
        Storage::disk('public')->put('.gitignore', '*');
        Storage::disk('local')->put('id-documents/id1.pdf', 'pdf-bytes');
        Storage::disk('local')->put('other/secret.txt', 'not migrated');

        $this->drama->update([
            'poster_url' => 'https://api.afriva.co.tz/storage/posters/p1.webp',
            'backdrop_url' => 'https://afrivamedia.b-cdn.net/storage/backdrops/b1.webp',
        ]);
        $this->episode(1)->update(['thumbnail_url' => '/storage/posters/missing.webp']);
        $this->company->update(['logo_url' => 'https://api.afriva.co.tz/storage/logos/l1.webp']);
        User::where('email', 'kilima-studios@afriva.com')->update(['avatar_url' => 'https://example.com/a.png']);

        $company = Company::create(['name' => 'Doc Co', 'slug' => 'doc-co', 'status' => 'pending']);
        StudioApplication::create([
            'company_id' => $company->id, 'full_name' => 'Asha', 'id_type' => 'nida', 'phone' => '+255700000002',
            'guidelines_accepted_at' => now(), 'creator_share_percent' => 60, 'id_document_path' => 'id-documents/id1.pdf',
        ]);
    }

    public function test_dry_run_reports_without_copying_or_rewriting(): void
    {
        $this->artisan('media:migrate-to-r2', ['--dry-run' => true])
            ->expectsOutputToContain('Dry run')
            ->expectsOutputToContain('Would rewrite 3 URL(s)')
            ->assertSuccessful();

        $this->assertSame([], Storage::disk('r2_public')->allFiles());
        $this->assertSame([], Storage::disk('r2_private')->allFiles());
        $this->assertSame('https://api.afriva.co.tz/storage/posters/p1.webp', $this->drama->fresh()->poster_url);
    }

    public function test_real_run_copies_rewrites_keeps_originals_and_is_idempotent(): void
    {
        $this->artisan('media:migrate-to-r2')->expectsOutputToContain('Rewrote 3 URL(s)')->assertSuccessful();

        Storage::disk('r2_public')->assertExists(['posters/p1.webp', 'backdrops/b1.webp', 'logos/l1.webp']);
        Storage::disk('r2_public')->assertMissing('.gitignore');
        $this->assertSame('poster-bytes', Storage::disk('r2_public')->get('posters/p1.webp'));
        Storage::disk('r2_private')->assertExists('id-documents/id1.pdf');
        Storage::disk('r2_private')->assertMissing('other/secret.txt');

        // Originals are never deleted.
        Storage::disk('public')->assertExists(['posters/p1.webp', 'backdrops/b1.webp', 'logos/l1.webp']);
        Storage::disk('local')->assertExists('id-documents/id1.pdf');

        $drama = $this->drama->fresh();
        $this->assertSame(self::R2.'/posters/p1.webp', $drama->poster_url);
        $this->assertSame(self::R2.'/backdrops/b1.webp', $drama->backdrop_url);
        $this->assertSame(self::R2.'/logos/l1.webp', $this->company->fresh()->logo_url);
        // Missing files and external URLs are left alone; ID document paths stay valid as they are.
        $this->assertSame('/storage/posters/missing.webp', $this->episode(1)->fresh()->thumbnail_url);
        $this->assertSame('https://example.com/a.png', User::where('email', 'kilima-studios@afriva.com')->value('avatar_url'));
        $this->assertSame('id-documents/id1.pdf', StudioApplication::value('id_document_path'));

        // Second run: nothing new to copy or rewrite.
        $this->artisan('media:migrate-to-r2')->expectsOutputToContain('Rewrote 0 URL(s)')->assertSuccessful();
        $this->assertSame(self::R2.'/posters/p1.webp', $this->drama->fresh()->poster_url);
    }

    public function test_real_run_refuses_without_a_public_url(): void
    {
        config(['filesystems.disks.r2_public.url' => null]);
        $this->artisan('media:migrate-to-r2')->expectsOutputToContain('R2_PUBLIC_URL')->assertFailed();
    }
}
