<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use RuntimeException;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Production: reference data + one super admin from env. Never the demo accounts (shared "password").
        if (app()->isProduction()) {
            $this->call(CoreSeeder::class);
            $this->seedProductionAdmin();

            return;
        }

        $this->call([
            CoreSeeder::class,      // settings, categories, plans, payment methods
            AccountSeeder::class,   // admin, companies + logins, demo viewers
            DramaSeeder::class,     // 32 original dramas + episodes
            ActivitySeeder::class,  // ~60 days of synthetic views/payments/subscriptions/earnings/payouts
        ]);
    }

    protected function seedProductionAdmin(): void
    {
        $email = env('ADMIN_EMAIL');
        $password = env('ADMIN_PASSWORD');
        if (! $email || ! $password || strlen($password) < 12) {
            throw new RuntimeException('Set ADMIN_EMAIL and ADMIN_PASSWORD (12+ characters) to seed the production super admin.');
        }

        User::firstOrCreate(['email' => $email], [
            'name' => env('ADMIN_NAME', 'Afriva Admin'),
            'password' => $password,
            'role' => User::ROLE_SUPER_ADMIN,
            'status' => 'active',
        ]);
    }
}
