<?php

namespace Tests\Feature;

use App\Models\ApplicationSample;
use App\Models\Company;
use App\Models\Setting;
use App\Models\StudioApplication;
use App\Models\User;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;

class StudioApplicationTest extends ApiTestCase
{
    protected function payload(array $overrides = []): array
    {
        return array_merge([
            'full_name' => 'Asha Juma Mrisho', 'studio_name' => 'Bongo Films',
            'id_type' => 'nida', 'id_number' => '19900101-12345-00001-23',
            'phone' => '+255700111222',
            'payout_method' => 'mobile_money', 'payout_provider' => 'mpesa',
            'payout_account_name' => 'Asha Juma', 'payout_account_number' => '+255700111222',
            'guidelines_accepted' => true,
            'email' => 'asha@bongofilms.co.tz', 'password' => 'secret-pass',
        ], $overrides);
    }

    protected function apply(array $overrides = [], ?string $token = null)
    {
        $req = $token ? $this->withToken($token) : $this;

        return $req->postJson('/api/v1/auth/studio-application', $this->payload($overrides));
    }

    protected function admin(): User
    {
        return User::firstOrCreate(['email' => 'boss@afriva.com'], ['name' => 'Admin', 'password' => 'password', 'role' => 'super_admin']);
    }

    protected function adminToken(): string
    {
        $this->app['auth']->forgetGuards();

        return $this->tokenFor($this->admin());
    }

    /** Gives the company's request $count ready samples of $seconds each. */
    protected function readySamples(Company $company, int $count = 10, int $seconds = 120): void
    {
        $app = StudioApplication::where('company_id', $company->id)->firstOrFail();
        for ($i = 1; $i <= $count; $i++) {
            $app->samples()->create(['bunny_video_id' => sprintf('00000000-0000-0000-0000-%012d', $company->id * 100 + $i), 'title' => "Sample $i", 'status' => 'ready', 'duration_seconds' => $seconds]);
        }
    }

    protected function bunnyConfig(): void
    {
        config(['services.bunny' => [
            'library_id' => '12345', 'api_key' => 'secret-api-key', 'cdn_hostname' => 'vz-test.b-cdn.net',
            'token_auth_key' => '', 'token_ttl' => 14400, 'webhook_secret' => '', 'enabled' => true,
        ]]);
    }

    public function test_guest_applicant_waits_for_approval_then_can_log_in(): void
    {
        $this->apply()->assertCreated()->assertJsonPath('data.status', 'pending')->assertJsonPath('data.existing_user', false);
        $company = Company::where('name', 'Bongo Films')->firstOrFail();
        $this->assertSame('pending', $company->status);
        $this->assertSame('mpesa', $company->payout_provider);
        $this->assertEquals(60, $company->revenue_share_percent);

        $app = StudioApplication::where('company_id', $company->id)->firstOrFail();
        $this->assertSame('19900101-12345-00001-23', $app->id_number);
        $this->assertNotNull($app->guidelines_accepted_at);
        $this->assertEquals(60, $app->creator_share_percent);
        // Encrypted at rest.
        $this->assertStringNotContainsString('12345', (string) \DB::table('studio_applications')->value('id_number'));

        // Pending logins can sign in to follow the request, but cannot use Studio or post.
        $pending = $this->postJson('/api/v1/auth/login', ['login' => 'asha@bongofilms.co.tz', 'password' => 'secret-pass'])
            ->assertOk()->assertJsonPath('data.user.status', 'pending')->json('data.token');
        $this->withToken($pending)->getJson('/api/v1/studio/dashboard')->assertStatus(403)->assertJsonPath('code', 'account_pending');
        $this->withToken($pending)->postJson('/api/v1/studio/dramas', ['title' => 'Sneaky'])->assertStatus(403);
        $this->withToken($pending)->getJson('/api/v1/me/studio-application')->assertOk()
            ->assertJsonPath('data.review_status', 'pending')->assertJsonPath('data.samples_summary.required', 10);

        $token = $this->adminToken();
        $this->withToken($token)->getJson('/api/v1/admin/companies')->assertOk()
            ->assertJsonPath('data.0.id', $company->id) // pending first
            ->assertJsonPath('data.0.application.full_name', 'Asha Juma Mrisho')
            ->assertJsonPath('data.0.application.id_number', '19900101-12345-00001-23')
            ->assertJsonPath('data.0.application.email', 'asha@bongofilms.co.tz')
            ->assertJsonPath('data.0.payout.provider', 'mpesa');

        // Not before 10 valid samples.
        $this->withToken($token)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])
            ->assertStatus(422)->assertJsonPath('code', 'samples_incomplete');
        $this->readySamples($company);
        $this->withToken($token)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])->assertOk();
        $this->assertSame('approved', $app->fresh()->status);

        $this->postJson('/api/v1/auth/login', ['login' => 'asha@bongofilms.co.tz', 'password' => 'secret-pass'])
            ->assertOk()->assertJsonPath('data.user.role', 'company')->assertJsonPath('data.user.company.id', $company->id);
    }

    public function test_logged_in_viewer_applies_and_becomes_studio_owner_on_approval(): void
    {
        $viewer = $this->viewer();
        $token = $this->tokenFor($viewer);
        $this->apply(['email' => null, 'password' => null, 'studio_name' => null], $token)
            ->assertCreated()->assertJsonPath('data.existing_user', true);

        $company = Company::where('name', 'Asha Juma Mrisho')->firstOrFail(); // defaults to the person's name
        $viewer->refresh();
        $this->assertSame('viewer', $viewer->role);
        $this->assertNull($viewer->company_id);
        $this->withToken($token)->getJson('/api/v1/me/studio-application')->assertOk()->assertJsonPath('data.status', 'pending');

        // A second request while one is waiting is refused.
        $this->apply(['email' => null, 'password' => null], $token)->assertStatus(422);

        $this->readySamples($company);
        $this->withToken($this->adminToken())->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])->assertOk();

        $viewer->refresh();
        $this->assertSame('company', $viewer->role);
        $this->assertSame($company->id, $viewer->company_id);
        $this->assertSame('active', $viewer->status);
    }

    public function test_guest_with_existing_viewer_email_must_use_its_password(): void
    {
        $viewer = $this->viewer(email: 'asha@bongofilms.co.tz');
        $this->apply(['password' => 'wrong-pass'])->assertStatus(422)->assertJsonValidationErrors(['password'], 'errors');
        $this->apply(['password' => 'password'])->assertCreated()->assertJsonPath('data.existing_user', true);
        $this->assertSame(1, User::where('email', 'asha@bongofilms.co.tz')->count());
        $this->assertSame($viewer->id, StudioApplication::value('user_id'));

        // Studio logins cannot be reused.
        $this->apply(['email' => 'kilima-studios@afriva.com', 'password' => 'password'])->assertStatus(422)->assertJsonValidationErrors(['email'], 'errors');
    }

    public function test_admin_rejects_with_reason_samples_are_deleted_at_bunny(): void
    {
        $this->bunnyConfig();
        Http::fake(['*' => Http::response(['success' => true])]);
        $this->apply()->assertCreated();
        $company = Company::where('name', 'Bongo Films')->firstOrFail();
        $this->readySamples($company, 3);
        $token = $this->adminToken();

        $this->withToken($token)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'rejected'])
            ->assertStatus(422)->assertJsonValidationErrors(['rejection_reason'], 'errors');
        $this->withToken($token)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'rejected', 'rejection_reason' => 'Sound quality is too low.'])
            ->assertOk()->assertJsonPath('data.status', 'rejected')->assertJsonPath('data.application.status', 'rejected')
            ->assertJsonPath('data.application.rejection_reason', 'Sound quality is too low.');

        Http::assertSentCount(3);
        Http::assertSent(fn (HttpRequest $r) => $r->method() === 'DELETE' && str_contains($r->url(), '/library/12345/videos/'));
        $this->assertSame(0, ApplicationSample::count());

        $this->postJson('/api/v1/auth/login', ['login' => 'asha@bongofilms.co.tz', 'password' => 'secret-pass'])
            ->assertStatus(403)->assertJsonPath('code', 'account_rejected')->assertJsonPath('reason', 'Sound quality is too low.');
    }

    public function test_sample_upload_returns_tus_credentials_and_follows_bunny(): void
    {
        $this->bunnyConfig();
        $guid = '11111111-2222-3333-4444-555555555555';
        $length = 45;
        Http::fake(function (HttpRequest $r) use ($guid, &$length) {
            if ($r->method() === 'POST') {
                return Http::response(['guid' => $guid, 'status' => 0]);
            }
            if ($r->method() === 'GET') {
                return Http::response(['guid' => $guid, 'status' => 4, 'length' => $length, 'availableResolutions' => '720p']);
            }

            return Http::response(['success' => true]);
        });
        $viewer = $this->viewer();
        $token = $this->tokenFor($viewer);
        $this->apply(['email' => null, 'password' => null], $token)->assertCreated();

        $res = $this->withToken($token)->postJson('/api/v1/me/studio-application/samples', ['title' => 'Trailer', 'size_bytes' => 50_000_000])
            ->assertCreated()->assertJsonPath('data.upload.video_id', $guid)->assertJsonPath('data.upload.library_id', '12345')
            ->assertJsonPath('data.upload.tus_endpoint', 'https://video.bunnycdn.com/tusupload');
        $this->assertArrayNotHasKey('api_key', $res->json('data.upload'));
        $this->assertSame(hash('sha256', '12345'.'secret-api-key'.$res->json('data.upload.expires').$guid), $res->json('data.upload.signature'));
        $id = $res->json('data.sample.id');

        // Too short: flagged so the applicant replaces it.
        $this->withToken($token)->postJson("/api/v1/me/studio-application/samples/{$id}/complete", ['video_id' => $guid])
            ->assertOk()->assertJsonPath('data.status', 'ready')->assertJsonPath('data.length_check', 'too_short')->assertJsonPath('data.valid', false);

        // Webhook path reads the real length.
        $length = 125;
        $this->postJson('/api/v1/webhooks/bunny', ['VideoLibraryId' => 12345, 'VideoGuid' => $guid, 'Status' => 3])->assertOk();
        $this->assertSame(125, ApplicationSample::find($id)->duration_seconds);
        $this->withToken($token)->getJson('/api/v1/me/studio-application')->assertJsonPath('data.samples.0.length_check', 'ok')
            ->assertJsonPath('data.samples_summary.valid', 1);

        // Too large files are refused; delete allows replacing.
        $this->withToken($token)->postJson('/api/v1/me/studio-application/samples', ['size_bytes' => 900_000_000])->assertStatus(422);
        $this->withToken($token)->deleteJson("/api/v1/me/studio-application/samples/{$id}")->assertOk();
        $this->assertSame(0, ApplicationSample::count());

        // Admin plays samples with signed URLs; others cannot.
        $company = Company::where('name', 'Bongo Films')->firstOrFail();
        $this->readySamples($company, 10, 200);
        $this->withToken($token)->getJson("/api/v1/admin/companies/{$company->id}/samples")->assertStatus(403);
        $admin = $this->adminToken();
        $this->withToken($admin)->getJson("/api/v1/admin/companies/{$company->id}/samples")->assertOk()
            ->assertJsonPath('data.samples_summary.valid', 0)
            ->assertJsonPath('data.samples.0.length_check', 'too_long')
            ->assertJsonPath('data.samples.0.playback_url', fn ($u) => str_starts_with($u, 'https://vz-test.b-cdn.net/'));
        // Too long samples do not count.
        $this->withToken($admin)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])->assertStatus(422);

        // Eleventh sample refused.
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->postJson('/api/v1/me/studio-application/samples')->assertStatus(422)->assertJsonPath('code', 'samples_full');
    }

    public function test_approval_with_ten_samples_in_range_gives_studio_access(): void
    {
        $this->apply()->assertCreated();
        $company = Company::where('name', 'Bongo Films')->firstOrFail();
        $this->readySamples($company, 9, 120);
        $app = StudioApplication::first();
        $app->samples()->create(['bunny_video_id' => '99999999-0000-0000-0000-000000000001', 'status' => 'ready', 'duration_seconds' => 59]);
        $token = $this->adminToken();
        $this->withToken($token)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])->assertStatus(422);

        $app->samples()->where('duration_seconds', 59)->update(['duration_seconds' => 180]);
        $this->withToken($token)->getJson('/api/v1/admin/companies')->assertJsonPath('data.0.application.review_status', 'ready_for_review');
        $this->withToken($token)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])->assertOk();

        $this->app['auth']->forgetGuards();
        $login = $this->postJson('/api/v1/auth/login', ['login' => 'asha@bongofilms.co.tz', 'password' => 'secret-pass'])->json('data.token');
        $this->app['auth']->forgetGuards();
        $this->withToken($login)->getJson('/api/v1/studio/dashboard')->assertOk();
    }

    public function test_id_number_or_document_is_required(): void
    {
        $this->apply(['id_number' => null])->assertStatus(422)->assertJsonValidationErrors(['id_number', 'id_document'], 'errors');
        $this->assertSame(0, Company::where('name', 'Bongo Films')->count());

        Storage::fake('local');
        $this->post('/api/v1/auth/studio-application', $this->payload([
            'id_number' => null, 'id_document' => UploadedFile::fake()->image('nida.jpg'), 'guidelines_accepted' => '1',
        ]), ['Accept' => 'application/json'])->assertCreated();
        $path = StudioApplication::value('id_document_path');
        $this->assertNotNull($path);
        Storage::disk('local')->assertExists($path);
    }

    public function test_guidelines_must_be_accepted_and_payout_is_validated(): void
    {
        $this->apply(['guidelines_accepted' => false])->assertStatus(422)->assertJsonValidationErrors(['guidelines_accepted'], 'errors');
        $this->apply(['payout_method' => 'bank', 'payout_provider' => null])->assertStatus(422)->assertJsonValidationErrors(['payout_bank_name'], 'errors');
        $this->apply(['payout_provider' => 'paypal'])->assertStatus(422)->assertJsonValidationErrors(['payout_provider'], 'errors');
        $this->assertSame(0, Company::where('name', 'Bongo Films')->count());
    }

    public function test_id_document_is_only_downloadable_by_super_admin(): void
    {
        Storage::fake('local');
        $this->post('/api/v1/auth/studio-application', $this->payload([
            'id_document' => UploadedFile::fake()->create('passport.pdf', 200, 'application/pdf'), 'id_type' => 'passport',
        ]), ['Accept' => 'application/json'])->assertCreated();
        $company = Company::where('name', 'Bongo Films')->firstOrFail();
        $url = "/api/v1/admin/companies/{$company->id}/id-document";

        $this->getJson($url)->assertStatus(401);
        $this->withToken($this->tokenFor($this->viewer()))->getJson($url)->assertStatus(403);
        $this->app['auth']->forgetGuards();
        $studio = User::where('email', 'kilima-studios@afriva.com')->first();
        $this->withToken($this->tokenFor($studio))->getJson($url)->assertStatus(403);
        $this->app['auth']->forgetGuards();
        $this->withToken($this->tokenFor($this->admin()))->get($url)->assertOk()->assertHeader('Cache-Control');

        // Never in public storage, never in the studio's own profile.
        Storage::disk('public')->assertMissing(StudioApplication::value('id_document_path'));
    }

    public function test_revenue_share_setting_feeds_guidelines_and_follows_on_non_custom_companies(): void
    {
        $this->getJson('/api/v1/creator-guidelines')->assertOk()
            ->assertJsonPath('data.creator_percent', 60)->assertJsonPath('data.platform_percent', 40);

        $follows = Company::create(['name' => 'Default Co', 'slug' => 'default-co', 'status' => 'active']);
        $this->assertEquals(60, $follows->revenue_share_percent);
        $custom = Company::create(['name' => 'Custom Co', 'slug' => 'custom-co', 'status' => 'active', 'revenue_share_percent' => 80]);

        $this->withToken($this->tokenFor($this->admin()))->putJson('/api/v1/admin/settings', ['creator_revenue_share_percent' => 65])
            ->assertOk();
        $this->assertEquals(65, Setting::creatorShare());

        $this->assertEquals(65, $follows->fresh()->revenue_share_percent);
        $this->assertEquals(80, $custom->fresh()->revenue_share_percent);
        $this->assertEquals(70, $this->company->fresh()->revenue_share_percent); // custom 70 untouched
        $this->getJson('/api/v1/creator-guidelines')->assertJsonPath('data.creator_percent', 65)->assertJsonPath('data.platform_percent', 35);

        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $this->apply()->assertCreated();
        $this->assertEquals(65, Company::where('name', 'Bongo Films')->value('revenue_share_percent'));
        $this->assertEquals(65, StudioApplication::value('creator_share_percent'));

        $this->withToken($this->tokenFor(User::where('role', 'super_admin')->first()))
            ->putJson('/api/v1/admin/settings', ['creator_revenue_share_percent' => 120])->assertStatus(422);
    }

    public function test_studio_can_edit_payout_details(): void
    {
        $studio = User::where('email', 'kilima-studios@afriva.com')->first();
        $this->withToken($this->tokenFor($studio))->putJson('/api/v1/studio/profile', [
            'payout_method' => 'bank', 'payout_bank_name' => 'CRDB', 'payout_account_name' => 'Kilima Studios Ltd', 'payout_account_number' => '0150123456789',
        ])->assertOk()->assertJsonPath('data.company.payout.bank_name', 'CRDB')->assertJsonPath('data.company.payout.method', 'bank');
    }
}
