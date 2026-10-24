<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            CoreSeeder::class,      // settings, categories, plans, payment methods
            AccountSeeder::class,   // admin, companies + logins, demo viewers
            DramaSeeder::class,     // 32 original dramas + episodes
            ActivitySeeder::class,  // ~60 days of synthetic views/payments/subscriptions/earnings/payouts
        ]);
    }
}
