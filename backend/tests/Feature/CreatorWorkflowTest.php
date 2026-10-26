<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Company;
use App\Models\Drama;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/** Scope §04: Tuma kazi → Kagua → Rekebisha → Chapisha. Upload never means published. */
class CreatorWorkflowTest extends ApiTestCase
{
    protected function staff(string $role): string
    {
        $user = User::create(['name' => ucfirst($role), 'email' => "{$role}@afriva.test", 'password' => 'password', 'role' => 'super_admin', 'staff_role' => $role]);

        return $this->tokenFor($user);
    }

    public function test_full_submission_review_and_publish_flow(): void
    {
        Storage::fake('public');
        Storage::fake('videos');

        // A viewer applies to become a creator; the account is pending until AFRIVA approves it.
        $viewer = $this->viewer(email: 'creator@afriva.test');
        $creator = $this->tokenFor($viewer);
        $this->withToken($creator)->postJson('/api/v1/creator/apply', ['name' => 'Pwani Films', 'country' => 'tz'])
            ->assertCreated()->assertJsonPath('data.user.role', 'company')->assertJsonPath('data.user.company.status', 'pending');
        $company = Company::where('name', 'Pwani Films')->firstOrFail();

        $drama = $this->withToken($creator)->post('/api/v1/studio/dramas', [
            'title' => 'Siri ya Usiku', 'synopsis' => 'Hadithi ya fumbo la usiku.',
            'category_ids' => [Category::where('slug', 'siri-na-mafumbo')->value('id')],
            'poster' => UploadedFile::fake()->image('poster.jpg', 600, 800),
            'trailer' => UploadedFile::fake()->create('trailer.mp4', 100, 'video/mp4'),
            'age_rating' => '13+',
            'status' => 'published', 'free_episodes' => 2, // publishing rules are ignored for creators
        ], ['Accept' => 'application/json'])->assertCreated()
            ->assertJsonPath('data.review_status', 'draft')->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.free_episodes', 8)->assertJsonPath('data.age_rating', '13+')
            ->json('data');
        $this->assertStringContainsString('/api/v1/media/videos/trailers/', $drama['trailer_url']);
        $id = $drama['id'];

        $this->withToken($creator)->post("/api/v1/studio/dramas/{$id}/episodes", [
            'video' => UploadedFile::fake()->create('ep1.mp4', 100, 'video/mp4'), 'duration_seconds' => 90,
        ], ['Accept' => 'application/json'])->assertCreated()->assertJsonPath('data.review_status', 'draft');

        // Not approved yet → cannot submit.
        $this->withToken($creator)->postJson("/api/v1/studio/dramas/{$id}/submit", ['rights_declaration' => true])
            ->assertForbidden()->assertJsonPath('code', 'creator_not_approved');

        $owner = $this->tokenFor(User::create(['name' => 'Owner', 'email' => 'owner@afriva.test', 'password' => 'password', 'role' => 'super_admin', 'staff_role' => 'owner']));
        $this->withToken($owner)->putJson("/api/v1/admin/companies/{$company->id}", ['status' => 'active'])->assertOk();

        $this->withToken($creator)->postJson("/api/v1/studio/dramas/{$id}/submit", ['rights_declaration' => true])
            ->assertForbidden()->assertJsonPath('code', 'agreement_required');
        $this->withToken($creator)->postJson('/api/v1/studio/agreement', ['accept' => true])->assertOk()->assertJsonPath('data.accepted', true);
        $this->withToken($creator)->postJson("/api/v1/studio/dramas/{$id}/submit", ['rights_declaration' => false])
            ->assertStatus(422)->assertJsonValidationErrors('rights_declaration');

        $this->withToken($creator)->postJson("/api/v1/studio/dramas/{$id}/submit", ['rights_declaration' => true])
            ->assertOk()->assertJsonPath('data.review_status', 'submitted')->assertJsonPath('data.episodes.0.review_status', 'submitted');

        // Locked while under review.
        $this->withToken($creator)->putJson("/api/v1/studio/dramas/{$id}", ['title' => 'Jina jipya'])
            ->assertStatus(409)->assertJsonPath('code', 'locked_for_review');

        // Reviewer requests changes; creator fixes and resubmits.
        $reviewer = $this->staff('reviewer');
        $this->withToken($reviewer)->getJson('/api/v1/admin/reviews')->assertOk()->assertJsonPath('meta.counts.pending', 1);
        $this->withToken($reviewer)->postJson("/api/v1/admin/reviews/{$id}/start")->assertOk()->assertJsonPath('data.review_status', 'in_review');
        $this->withToken($reviewer)->postJson("/api/v1/admin/reviews/{$id}/decide", ['decision' => 'request_changes'])
            ->assertStatus(422)->assertJsonValidationErrors('notes');
        $this->withToken($reviewer)->postJson("/api/v1/admin/reviews/{$id}/decide", ['decision' => 'request_changes', 'notes' => 'Sauti iko chini sana.'])
            ->assertOk()->assertJsonPath('data.review_status', 'changes_requested');

        $this->withToken($creator)->getJson("/api/v1/studio/dramas/{$id}")
            ->assertJsonPath('data.review_notes', 'Sauti iko chini sana.')
            ->assertJsonPath('data.reviews.0.action', 'request_changes');
        $epId = $this->withToken($creator)->getJson("/api/v1/studio/dramas/{$id}")->json('data.episodes.0.id');
        $this->withToken($creator)->post("/api/v1/studio/dramas/{$id}/episodes/{$epId}", [
            '_method' => 'PUT', 'video' => UploadedFile::fake()->create('ep1-v2.mp4', 100, 'video/mp4'),
        ], ['Accept' => 'application/json'])->assertOk();
        $this->withToken($creator)->postJson("/api/v1/studio/dramas/{$id}/submit", ['rights_declaration' => true])->assertOk();

        // Approval needs a playback check of every episode.
        $this->withToken($reviewer)->postJson("/api/v1/admin/reviews/{$id}/decide", ['decision' => 'approve'])
            ->assertStatus(422)->assertJsonValidationErrors('episodes');
        $this->withToken($reviewer)->postJson("/api/v1/admin/episodes/{$epId}/verify-playback")->assertOk();
        $this->withToken($reviewer)->postJson("/api/v1/admin/reviews/{$id}/decide", ['decision' => 'approve'])
            ->assertOk()->assertJsonPath('data.review_status', 'approved');

        // Approved but not published: still invisible to viewers.
        $slug = $drama['slug'];
        $this->getJson("/api/v1/dramas/{$slug}")->assertNotFound();

        // Reviewers cannot publish; editors can. Scheduled in the future = not live yet.
        $this->withToken($reviewer)->postJson("/api/v1/admin/dramas/{$id}/publish")->assertForbidden();
        $editor = $this->staff('editor');
        $this->withToken($editor)->postJson("/api/v1/admin/dramas/{$id}/publish", [
            'publish_at' => now()->addDay()->toIso8601String(), 'free_episodes' => 1, 'coins_per_episode' => 40,
        ])->assertOk()->assertJsonPath('data.is_scheduled', true)->assertJsonPath('data.is_live', false);
        $this->getJson("/api/v1/dramas/{$slug}")->assertNotFound();

        $this->withToken($editor)->postJson("/api/v1/admin/dramas/{$id}/publish", ['free_episodes' => 1])->assertOk()->assertJsonPath('data.is_live', true);
        $this->getJson("/api/v1/dramas/{$slug}")->assertOk()
            ->assertJsonPath('data.total_episodes', 1)
            ->assertJsonPath('data.total_duration_seconds', 90)
            ->assertJsonPath('data.episodes.0.access', 'free');

        $this->assertDatabaseHas('audit_logs', ['action' => 'drama.publish', 'subject_id' => $id]);
        $this->assertDatabaseHas('audit_logs', ['action' => 'creator.approve', 'subject_id' => $company->id]);

        // New episodes of a live series go through review too and stay hidden until approved.
        $this->withToken($creator)->post("/api/v1/studio/dramas/{$id}/episodes", [
            'video' => UploadedFile::fake()->create('ep2.mp4', 100, 'video/mp4'),
        ], ['Accept' => 'application/json'])->assertCreated();
        $this->getJson("/api/v1/dramas/{$slug}")->assertJsonCount(1, 'data.episodes');
    }

    public function test_staff_roles_limit_access(): void
    {
        $reviewer = $this->staff('reviewer');
        $finance = $this->staff('finance');
        $editor = $this->staff('editor');

        $this->withToken($reviewer)->getJson('/api/v1/admin/payments')->assertForbidden();
        $this->withToken($reviewer)->getJson('/api/v1/admin/reviews')->assertOk();
        $this->withToken($finance)->getJson('/api/v1/admin/reviews')->assertForbidden();
        $this->withToken($finance)->getJson('/api/v1/admin/payments')->assertOk();
        $this->withToken($finance)->getJson('/api/v1/admin/analytics')->assertOk();
        $this->withToken($editor)->getJson('/api/v1/admin/staff')->assertForbidden();
        $this->withToken($editor)->getJson('/api/v1/admin/audit-logs')->assertForbidden();
        $this->withToken($editor)->getJson('/api/v1/admin/videos')->assertOk();

        $this->withToken($finance)->getJson('/api/v1/auth/me')->assertJsonPath('data.staff_role', 'finance')
            ->assertJsonPath('data.permissions', ['dashboard', 'finance', 'analytics']);
    }

    public function test_owner_manages_staff_and_cannot_remove_last_owner(): void
    {
        $ownerUser = User::create(['name' => 'Owner', 'email' => 'owner@afriva.test', 'password' => 'password', 'role' => 'super_admin', 'staff_role' => 'owner']);
        $owner = $this->tokenFor($ownerUser);

        $this->withToken($owner)->postJson('/api/v1/admin/staff', [
            'name' => 'Neema', 'email' => 'neema@afriva.test', 'password' => 'password123', 'staff_role' => 'reviewer',
        ])->assertCreated()->assertJsonPath('data.staff_role', 'reviewer');
        $this->withToken($owner)->putJson("/api/v1/admin/staff/{$ownerUser->id}", ['staff_role' => 'editor'])
            ->assertStatus(422)->assertJsonPath('code', 'last_owner');
        $this->withToken($owner)->getJson('/api/v1/admin/audit-logs')->assertOk()->assertJsonPath('data.0.action', 'staff.create');
    }

    public function test_viewers_can_report_a_series(): void
    {
        $this->postJson("/api/v1/dramas/{$this->drama->id}/report", ['reason' => 'copyright'])
            ->assertStatus(422)->assertJsonValidationErrors('details');
        $this->postJson("/api/v1/dramas/{$this->drama->id}/report", ['reason' => 'copyright', 'details' => 'Hii ni kazi yangu.'])
            ->assertCreated();

        $owner = $this->tokenFor(User::create(['name' => 'Owner', 'email' => 'owner@afriva.test', 'password' => 'password', 'role' => 'super_admin']));
        $id = $this->withToken($owner)->getJson('/api/v1/admin/reports')->assertOk()->assertJsonPath('meta.open', 1)->json('data.0.id');
        $this->withToken($owner)->putJson("/api/v1/admin/reports/{$id}", ['status' => 'resolved', 'resolution_notes' => 'Imeondolewa'])
            ->assertOk()->assertJsonPath('data.status', 'resolved');
    }

    public function test_admin_reorders_episodes(): void
    {
        $owner = $this->tokenFor(User::create(['name' => 'Owner', 'email' => 'owner@afriva.test', 'password' => 'password', 'role' => 'super_admin']));
        $ids = $this->drama->episodes()->pluck('id')->all();
        $reversed = array_reverse($ids);

        $this->withToken($owner)->postJson("/api/v1/admin/dramas/{$this->drama->id}/episodes/reorder", ['episode_ids' => $reversed])
            ->assertOk()->assertJsonPath('data.0.id', $reversed[0])->assertJsonPath('data.0.number', 1);
        $this->withToken($owner)->postJson("/api/v1/admin/dramas/{$this->drama->id}/episodes/reorder", ['episode_ids' => [$ids[0]]])
            ->assertStatus(422);
    }

    public function test_default_free_preview_is_eight_episodes(): void
    {
        $this->assertSame(8, (new Drama)->free_episodes);
    }
}
