<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class AdminStudioTest extends ApiTestCase
{
    protected function admin(): User
    {
        return User::create(['name' => 'Admin', 'email' => 'admin@afriva.com', 'password' => 'password', 'role' => 'super_admin']);
    }

    protected function studioToken(string $slug): string
    {
        return $this->postJson('/api/v1/auth/login', ['login' => "$slug@afriva.com", 'password' => 'password'])->json('data.token');
    }

    public function test_studio_cannot_see_another_companys_drama(): void
    {
        $other = $this->makeCompany('Lagos Reel House', 'lagos-reel-house');
        $otherDrama = $this->makeDrama($other, 'Divorced, Then Crowned', 4);
        $token = $this->studioToken('kilima-studios');

        $this->withToken($token)->getJson("/api/v1/studio/dramas/{$this->drama->id}")->assertOk()
            ->assertJsonPath('data.id', $this->drama->id)
            ->assertJsonCount(10, 'data.episodes');

        $this->withToken($token)->getJson("/api/v1/studio/dramas/{$otherDrama->id}")->assertNotFound()->assertJsonPath('code', 'not_found');
        $this->withToken($token)->putJson("/api/v1/studio/dramas/{$otherDrama->id}", ['title' => 'Hacked'])->assertNotFound();
        $this->withToken($token)->postJson("/api/v1/studio/dramas/{$otherDrama->id}/episodes", ['video_url' => 'x'])->assertNotFound();
        $this->withToken($token)->deleteJson("/api/v1/studio/dramas/{$otherDrama->id}")->assertNotFound();

        $ids = collect($this->withToken($token)->getJson('/api/v1/studio/dramas')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($this->drama->id));
        $this->assertFalse($ids->contains($otherDrama->id));
        $this->assertSame('Divorced, Then Crowned', $otherDrama->fresh()->title);
    }

    public function test_studio_dashboard_and_create_drama_with_upload(): void
    {
        Storage::fake('public');
        Storage::fake('videos');
        $token = $this->studioToken('kilima-studios');

        $this->withToken($token)->getJson('/api/v1/studio/dashboard')->assertOk()
            ->assertJsonStructure(['data' => ['views' => ['total', 'today', 'last_30d'], 'unique_watchers',
                'earnings' => ['total', 'month', 'pending_payout'], 'views_chart' => [['date', 'value']], 'earnings_chart', 'dramas']])
            ->assertJsonCount(30, 'data.views_chart');

        $res = $this->withToken($token)->post('/api/v1/studio/dramas', [
            'title' => 'Love in Stone Town', 'synopsis' => 'Test', 'status' => 'draft', 'tags' => 'Forbidden Love, Coastal',
            'poster' => UploadedFile::fake()->image('poster.jpg', 600, 800),
            'company_id' => 999, // ignored for studio
        ], ['Accept' => 'application/json'])->assertCreated();
        $dramaId = $res->json('data.id');
        $this->assertSame($this->company->id, $res->json('data.company.id'));
        $this->assertStringContainsString('/storage/posters/', $res->json('data.poster_url'));
        $this->assertSame(['Forbidden Love', 'Coastal'], $res->json('data.tags'));

        $this->withToken($token)->post("/api/v1/studio/dramas/{$dramaId}/episodes", [
            'title' => 'Pilot', 'video' => UploadedFile::fake()->create('ep1.mp4', 100, 'video/mp4'), 'duration_seconds' => 120,
        ], ['Accept' => 'application/json'])->assertCreated()->assertJsonPath('data.number', 1);

        // Uploading does not publish: the series and its episode stay drafts until submitted and approved.
        $this->withToken($token)->getJson("/api/v1/studio/dramas/{$dramaId}")
            ->assertJsonPath('data.review_status', 'draft')
            ->assertJsonPath('data.total_episodes', 0)
            ->assertJsonCount(1, 'data.episodes')
            ->assertJsonPath('data.episodes.0.review_status', 'draft')
            ->assertJsonPath('data.free_episodes', 8);
    }

    public function test_viewer_and_company_cannot_access_admin(): void
    {
        $viewer = $this->viewer();
        $this->withToken($this->tokenFor($viewer))->getJson('/api/v1/admin/dashboard')->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->app['auth']->forgetGuards();
        $this->withToken($this->studioToken('kilima-studios'))->getJson('/api/v1/admin/dashboard')->assertForbidden();
    }

    public function test_admin_creates_company_and_owner_can_login(): void
    {
        $token = $this->tokenFor($this->admin());

        $this->withToken($token)->postJson('/api/v1/admin/companies', [
            'name' => 'Savannah Pictures', 'country' => 'KE', 'revenue_share_percent' => 65,
            'owner_name' => 'Wanjiru Kariuki', 'owner_email' => 'savannah-pictures@afriva.com', 'owner_password' => 'secret123',
        ])->assertCreated()
            ->assertJsonPath('data.slug', 'savannah-pictures')
            ->assertJsonPath('data.revenue_share_percent', 65)
            ->assertJsonPath('data.owner.email', 'savannah-pictures@afriva.com');

        $this->app['auth']->forgetGuards(); // the test client reuses the app (and its cached guard user) between requests
        $login = $this->postJson('/api/v1/auth/login', ['login' => 'savannah-pictures@afriva.com', 'password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('data.user.role', 'company')
            ->assertJsonPath('data.user.company.slug', 'savannah-pictures');

        $this->app['auth']->forgetGuards();
        $this->withToken($login->json('data.token'))->getJson('/api/v1/studio/dramas')->assertOk()->assertJsonPath('meta.total', 0);
    }

    public function test_admin_dashboard_and_lists(): void
    {
        $token = $this->tokenFor($this->admin());

        $this->withToken($token)->getJson('/api/v1/admin/dashboard')->assertOk()
            ->assertJsonStructure(['data' => ['totals' => ['revenue', 'revenue_today', 'revenue_month', 'users', 'active_subscribers', 'companies', 'dramas', 'views'],
                'revenue_chart' => [['date', 'value']], 'top_dramas', 'recent_payments', 'revenue_by_method']])
            ->assertJsonCount(30, 'data.revenue_chart');

        $this->withToken($token)->getJson('/api/v1/admin/users?role=company')->assertOk()->assertJsonPath('meta.total', 1);
        $this->withToken($token)->getJson('/api/v1/admin/payment-methods')->assertOk()->assertJsonCount(11, 'data');
        $this->withToken($token)->putJson('/api/v1/admin/payment-methods/1', ['is_enabled' => false])->assertOk()->assertJsonPath('data.is_enabled', false);
        $this->getJson('/api/v1/payment-methods')->assertJsonCount(5, 'data');
        $this->withToken($token)->getJson("/api/v1/admin/companies/{$this->company->id}/stats")->assertOk()->assertJsonStructure(['data' => ['views', 'earnings', 'views_chart']]);
        $this->withToken($token)->putJson('/api/v1/admin/settings', ['coin_value_tzs' => 12])->assertOk()->assertJsonPath('data.coin_value_tzs', '12');
        $this->withToken($token)->postJson('/api/v1/admin/payouts', ['company_id' => $this->company->id, 'amount' => 5000, 'status' => 'paid'])
            ->assertCreated()->assertJsonPath('data.status', 'paid');
        $this->withToken($token)->getJson("/api/v1/admin/dramas/{$this->drama->id}/episodes")->assertOk()->assertJsonCount(10, 'data');
    }
}
