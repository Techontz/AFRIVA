<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SiteInfoTest extends TestCase
{
    use RefreshDatabase;

    public function test_social_links_are_empty_until_set(): void
    {
        $this->getJson('/api/v1/site-info')->assertOk()->assertJsonPath('data.social.facebook', '');
    }

    public function test_admin_can_set_and_clear_a_link_and_the_public_endpoint_follows(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin'])->fresh());

        $this->putJson('/api/v1/admin/settings', ['social_tiktok' => 'https://tiktok.com/@afriva'])->assertOk();
        $this->getJson('/api/v1/site-info')->assertJsonPath('data.social.tiktok', 'https://tiktok.com/@afriva');

        $this->putJson('/api/v1/admin/settings', ['social_tiktok' => ''])->assertOk();
        $this->getJson('/api/v1/site-info')->assertJsonPath('data.social.tiktok', '');
    }

    public function test_unsafe_links_are_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'super_admin'])->fresh());

        $this->putJson('/api/v1/admin/settings', ['social_tiktok' => 'javascript:alert(1)'])->assertStatus(422);
        $this->putJson('/api/v1/admin/settings', ['settings' => ['social_tiktok' => 'javascript:alert(1)']])->assertStatus(422);
        $this->assertNull(Setting::where('key', 'social_tiktok')->value('value'));
    }
}
