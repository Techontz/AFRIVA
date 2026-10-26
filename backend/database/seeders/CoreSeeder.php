<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\PaymentMethod;
use App\Models\Plan;
use App\Models\Setting;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

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

        // Scope §03 categories (Kiswahili).
        $categories = ['Mapenzi', 'Historia', 'Siri na Mafumbo', 'Vita na Mashujaa', 'Vichekesho', 'Upelelezi', 'Maisha', 'Hadithi za Afrika'];
        foreach ($categories as $i => $name) {
            Category::updateOrCreate(['slug' => Str::slug($name)], ['name' => $name, 'sort_order' => $i + 1]);
        }

        $vipFeatures = ['Episode zote bila kikomo', 'Episode mpya kila siku', 'Ubora wa HD', 'Bila matangazo'];
        // [old English name (for upgrading existing rows), plan]
        $plans = [
            ['Weekly VIP', ['name' => 'VIP ya Wiki', 'type' => 'weekly', 'price' => 3000, 'duration_days' => 7,
                'description' => 'Siku 7 za kutazama series zote za AFRIVA.', 'features' => $vipFeatures]],
            ['Monthly VIP', ['name' => 'VIP ya Mwezi', 'type' => 'monthly', 'price' => 10000, 'duration_days' => 30, 'is_popular' => true,
                'description' => 'Siku 30 za kutazama series zote. Inayopendwa zaidi!', 'features' => $vipFeatures]],
            ['Yearly VIP', ['name' => 'VIP ya Mwaka', 'type' => 'yearly', 'price' => 90000, 'duration_days' => 365,
                'description' => 'Mwaka mzima wa AFRIVA. Okoa 25% ukilinganisha na mwezi.', 'features' => array_merge($vipFeatures, ['Thamani bora'])]],
            ['6 Episodes', ['name' => 'Episode 6', 'type' => 'episodes', 'price' => 10000, 'episode_quota' => 6,
                'description' => 'Fungua episode zozote 6 zilizofungwa, haziishi muda.', 'features' => ['Fungua episode zozote 6', 'Haziishi muda']]],
            ['15 Episodes', ['name' => 'Episode 15', 'type' => 'episodes', 'price' => 20000, 'episode_quota' => 15,
                'description' => 'Fungua episode zozote 15 zilizofungwa, haziishi muda.', 'features' => ['Fungua episode zozote 15', 'Haziishi muda']]],
            ['100 Coins', ['name' => 'Coins 100', 'type' => 'coins', 'price' => 1000, 'coins' => 100, 'bonus_coins' => 0,
                'description' => 'Ongeza coins 100 za kufungua episode.', 'features' => ['Coins 100']]],
            ['550 Coins', ['name' => 'Coins 550', 'type' => 'coins', 'price' => 5000, 'coins' => 500, 'bonus_coins' => 50,
                'description' => 'Coins 500 + bonasi ya coins 50.', 'features' => ['Coins 500', '+50 bonasi']]],
        ];
        foreach ($plans as $i => [$oldName, $p]) {
            Plan::where('name', $oldName)->update(['name' => $p['name']]);
            Plan::updateOrCreate(['name' => $p['name']], array_merge([
                'currency' => 'TZS', 'is_popular' => false, 'is_active' => true, 'sort_order' => $i + 1,
                'duration_days' => null, 'episode_quota' => null, 'coins' => null, 'bonus_coins' => null,
            ], $p));
        }

        // Scope §07: Tanzania mobile money + international cards/wallets. Banks and T-Pesa are kept but off.
        // Nothing is marked integrated: a method is only switched on after a successful test with its provider.
        $methods = [
            ['mpesa', 'M-Pesa', 'mobile_money', '#E60000', true],
            ['tigopesa', 'Mixx by Yas (Tigo Pesa)', 'mobile_money', '#00377B', true],
            ['airtelmoney', 'Airtel Money', 'mobile_money', '#ED1C24', true],
            ['halopesa', 'HaloPesa', 'mobile_money', '#F7941D', true],
            ['visa', 'Visa', 'card', '#1A1F71', true],
            ['mastercard', 'Mastercard', 'card', '#EB001B', true],
            ['wallet', 'Wallet ya kidijitali', 'card', '#111827', false],
            ['tpesa', 'T-Pesa', 'mobile_money', '#0072BC', false],
            ['crdb', 'CRDB Bank', 'bank', '#00A651', false],
            ['nmb', 'NMB Bank', 'bank', '#005BAA', false],
            ['nbc', 'NBC Bank', 'bank', '#002F6C', false],
        ];
        foreach ($methods as $i => [$code, $name, $type, $color, $enabled]) {
            $method = PaymentMethod::firstOrNew(['code' => $code]);
            $method->fill(['name' => $name, 'type' => $type, 'color' => $color, 'sort_order' => $i + 1]);
            if (! $method->exists) {
                $method->fill(['logo_url' => null, 'is_enabled' => $enabled, 'is_integrated' => false]);
            }
            $method->save();
        }
    }
}
