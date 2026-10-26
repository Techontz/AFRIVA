<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Company;
use App\Models\Drama;
use App\Models\Episode;
use App\Models\User;
use Database\Seeders\CoreSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

abstract class ApiTestCase extends TestCase
{
    use RefreshDatabase;

    protected Company $company;

    protected Drama $drama;

    protected function setUp(): void
    {
        parent::setUp();
        config(['payments.sandbox.auto_approve' => true]);
        $this->seed(CoreSeeder::class);

        $this->company = $this->makeCompany('Kilima Studios', 'kilima-studios');
        $this->drama = $this->makeDrama($this->company, 'The Chief\'s Hidden Heir', 10, freeEpisodes: 3);
    }

    protected function makeCompany(string $name, string $slug): Company
    {
        $company = Company::create(['name' => $name, 'slug' => $slug, 'country' => 'TZ', 'revenue_share_percent' => 70, 'status' => 'active']);
        User::create(['name' => "$name Admin", 'email' => "$slug@afriva.com", 'password' => 'password', 'role' => 'company', 'company_id' => $company->id]);

        return $company;
    }

    protected function makeDrama(Company $company, string $title, int $episodes, int $freeEpisodes = 5, int $coins = 30): Drama
    {
        $drama = Drama::create([
            'company_id' => $company->id, 'title' => $title, 'slug' => Drama::uniqueSlug($title),
            'synopsis' => 'A test synopsis.', 'poster_url' => 'https://example.com/p.jpg', 'backdrop_url' => 'https://example.com/b.jpg',
            'free_episodes' => $freeEpisodes, 'coins_per_episode' => $coins, 'status' => 'published', 'review_status' => 'approved',
            'is_featured' => true, 'badge' => 'hot', 'language' => 'sw', 'release_date' => now()->subDays(3)->toDateString(), 'views' => 1000,
        ]);
        $drama->categories()->attach(Category::where('slug', 'mapenzi')->value('id'));
        for ($n = 1; $n <= $episodes; $n++) {
            Episode::create(['drama_id' => $drama->id, 'number' => $n, 'title' => "Episode $n",
                'video_url' => "https://videos.example.com/$n.mp4", 'duration_seconds' => 90,
                'review_status' => 'approved', 'playback_verified_at' => now()]);
        }
        $drama->refreshEpisodeCount();

        return $drama->fresh();
    }

    protected function viewer(int $coins = 0, string $email = 'viewer@afriva.com'): User
    {
        return User::create(['name' => 'Viewer', 'email' => $email, 'password' => 'password', 'role' => 'viewer', 'coins' => $coins]);
    }

    /** Tests switch between users' tokens; forget the guard's cached user so each request authenticates afresh. */
    public function withToken(string $token, string $type = 'Bearer'): static
    {
        $this->app['auth']->forgetGuards();

        return parent::withToken($token, $type);
    }

    protected function tokenFor(User $user): string
    {
        return $user->createToken('test')->plainTextToken;
    }

    protected function episode(int $number): Episode
    {
        return $this->drama->episodes()->where('number', $number)->firstOrFail();
    }
}
