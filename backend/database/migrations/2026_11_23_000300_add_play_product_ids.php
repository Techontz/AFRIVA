<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** Google Play product ids (one-time, consumable products) for the Play Store build of the app. */
    public const IDS = [
        'Weekly VIP' => 'afriva_vip_weekly',
        'Monthly VIP' => 'afriva_vip_monthly',
        'Yearly VIP' => 'afriva_vip_yearly',
        '7 Episodes' => 'afriva_pack_7',
        'Full Series (30 Episodes)' => 'afriva_pack_series',
        '100 Coins' => 'afriva_coins_100',
        '550 Coins' => 'afriva_coins_550',
    ];

    public function up(): void
    {
        Schema::table('plans', function (Blueprint $table) {
            $table->string('play_product_id', 100)->nullable()->unique()->after('sort_order');
        });
        foreach (self::IDS as $name => $id) {
            DB::table('plans')->where('name', $name)->where('is_active', true)->update(['play_product_id' => $id]);
        }
        if (! DB::table('payment_methods')->where('code', 'google_play')->exists()) {
            // Recorded on Play Store purchases only; never offered at the normal checkout.
            DB::table('payment_methods')->insert([
                'code' => 'google_play', 'name' => 'Google Play', 'type' => 'store', 'is_enabled' => false,
                'is_integrated' => true, 'sort_order' => 90, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('plans', function (Blueprint $table) {
            $table->dropUnique(['play_product_id']);
            $table->dropColumn('play_product_id');
        });
    }
};
