<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Models\Setting;
use Illuminate\Database\Seeder;

/**
 * Reference data: settings, categories, plans, payment methods. Safe to re-run (upserts).
 */
class CoreSeeder extends Seeder
{
    public function run(): void
    {
        foreach (Setting::DEFAULTS as $key => $value) {
            Setting::updateOrCreate(['key' => $key], ['value' => $value]);
        }
        Setting::updateOrCreate(['key' => 'contact_business'], ['value' => 'business@afriva.com']);
        Setting::updateOrCreate(['key' => 'contact_press'], ['value' => 'press@afriva.com']);

        $categories = ['Romance', 'Revenge', 'Billionaire', 'Family', 'Comedy', 'Thriller', 'Historical', 'Village Life', 'Campus'];
        foreach ($categories as $i => $name) {
            Category::updateOrCreate(['slug' => \Illuminate\Support\Str::slug($name)], ['name' => $name, 'sort_order' => $i + 1]);
        }

        $vipFeatures = ['Unlimited access to all episodes', 'New episodes daily', 'HD streaming', 'No ads'];
        $plans = [
            ['name' => 'Weekly VIP', 'type' => 'weekly', 'price' => 3000, 'duration_days' => 7,
                'description' => '7 days of unlimited Afriva dramas.', 'features' => $vipFeatures],
            ['name' => 'Monthly VIP', 'type' => 'monthly', 'price' => 10000, 'duration_days' => 30, 'is_popular' => true,
                'description' => '30 days of unlimited Afriva dramas. Most popular!', 'features' => $vipFeatures],
            ['name' => 'Yearly VIP', 'type' => 'yearly', 'price' => 90000, 'duration_days' => 365,
                'description' => 'A full year of Afriva — save 25% vs monthly.', 'features' => array_merge($vipFeatures, ['Best value'])],
            ['name' => '6 Episodes', 'type' => 'episodes', 'price' => 10000, 'episode_quota' => 6,
                'description' => 'Unlock any 6 locked episodes, no expiry.', 'features' => ['Unlock any 6 episodes', 'Never expires']],
            ['name' => '15 Episodes', 'type' => 'episodes', 'price' => 20000, 'episode_quota' => 15,
                'description' => 'Unlock any 15 locked episodes, no expiry.', 'features' => ['Unlock any 15 episodes', 'Never expires']],
            ['name' => '100 Coins', 'type' => 'coins', 'price' => 1000, 'coins' => 100, 'bonus_coins' => 0,
                'description' => 'Top up 100 coins to unlock episodes.', 'features' => ['100 coins']],
            ['name' => '550 Coins', 'type' => 'coins', 'price' => 5000, 'coins' => 500, 'bonus_coins' => 50,
                'description' => '500 coins + 50 bonus coins.', 'features' => ['500 coins', '+50 bonus coins']],
        ];
        foreach ($plans as $i => $p) {
            Plan::updateOrCreate(['name' => $p['name']], array_merge([
                'currency' => 'TZS', 'is_popular' => false, 'is_active' => true, 'sort_order' => $i + 1,
                'duration_days' => null, 'episode_quota' => null, 'coins' => null, 'bonus_coins' => null,
            ], $p));
        }

        $methods = [
            ['mpesa', 'M-Pesa', 'mobile_money', '#E60000'],
            ['tigopesa', 'Mixx by Yas (Tigo Pesa)', 'mobile_money', '#00377B'],
            ['airtelmoney', 'Airtel Money', 'mobile_money', '#ED1C24'],
            ['halopesa', 'HaloPesa', 'mobile_money', '#F7941D'],
            ['tpesa', 'T-Pesa', 'mobile_money', '#0072BC'],
            ['visa', 'Visa', 'card', '#1A1F71'],
            ['mastercard', 'Mastercard', 'card', '#EB001B'],
            ['crdb', 'CRDB Bank', 'bank', '#00A651'],
            ['nmb', 'NMB Bank', 'bank', '#005BAA'],
            ['nbc', 'NBC Bank', 'bank', '#002F6C'],
        ];
        foreach ($methods as $i => [$code, $name, $type, $color]) {
            PaymentMethod::updateOrCreate(['code' => $code], [
                'name' => $name, 'type' => $type, 'color' => $color, 'logo_url' => null,
                'is_enabled' => true, 'is_integrated' => false, 'sort_order' => $i + 1,
            ]);
        }
    }
}
