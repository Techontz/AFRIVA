<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Super admin, the four studios (+ their logins) and the two demo viewers.
 */
class AccountSeeder extends Seeder
{
    public const COMPANIES = [
        ['Kilima Studios', 'kilima-studios', 'TZ', 70.00, '+255 22 211 0001',
            'Dar es Salaam production house behind some of Tanzania\'s most-watched vertical dramas.'],
        ['Savannah Pictures', 'savannah-pictures', 'KE', 65.00, '+254 20 765 0002',
            'Nairobi studio telling bold East African stories, from the ridges to the coast.'],
        ['Lagos Reel House', 'lagos-reel-house', 'NG', 70.00, '+234 1 280 0003',
            'Fast-paced Nollywood-style romance, comedy and revenge series made in Lagos.'],
        ['Zanzibar Tales', 'zanzibar-tales', 'TZ', 75.00, '+255 24 223 0004',
            'Stories from Stone Town and the Swahili coast — history, mystery and love by the ocean.'],
    ];

    public function run(): void
    {
        User::updateOrCreate(['email' => 'admin@afriva.com'], [
            'name' => 'Afriva Admin', 'password' => 'password', 'role' => User::ROLE_SUPER_ADMIN, 'status' => 'active',
        ]);

        foreach (self::COMPANIES as [$name, $slug, $country, $share, $phone, $desc]) {
            $company = Company::updateOrCreate(['slug' => $slug], [
                'name' => $name,
                'email' => "{$slug}@afriva.com",
                'phone' => $phone,
                'country' => $country,
                'revenue_share_percent' => $share,
                'status' => 'active',
                'description' => $desc,
                'logo_url' => "https://picsum.photos/seed/afriva-logo-{$slug}/200/200",
            ]);
            User::updateOrCreate(['email' => "{$slug}@afriva.com"], [
                'name' => "{$name} Admin", 'password' => 'password', 'role' => User::ROLE_COMPANY,
                'company_id' => $company->id, 'status' => 'active',
            ]);
        }

        User::updateOrCreate(['email' => 'viewer@afriva.com'], [
            'name' => 'Asha Mwakyusa', 'phone' => '+255712000001', 'password' => 'password',
            'role' => User::ROLE_VIEWER, 'coins' => 200, 'status' => 'active',
        ]);
        User::updateOrCreate(['email' => 'vip@afriva.com'], [
            'name' => 'Baraka Kimaro', 'phone' => '+255754000002', 'password' => 'password',
            'role' => User::ROLE_VIEWER, 'coins' => 120, 'status' => 'active',
        ]);
    }
}
