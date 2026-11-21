<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * New episode packs: TZS 1,000 for 7 episodes and TZS 1,500 for a full series (30 episodes).
     * The old packs are switched off, not deleted, so past purchases and earnings keep their plan.
     */
    public function up(): void
    {
        DB::table('plans')->whereIn('name', ['6 Episodes', '15 Episodes'])->update(['is_active' => false, 'updated_at' => now()]);

        $packs = [
            ['name' => '7 Episodes', 'price' => 1000, 'episode_quota' => 7, 'sort_order' => 4,
                'description' => 'Unlock any 7 locked episodes, no expiry.',
                'features' => ['Unlock any 7 episodes', 'Never expires']],
            ['name' => 'Full Series (30 Episodes)', 'price' => 1500, 'episode_quota' => 30, 'sort_order' => 5, 'is_popular' => true,
                'description' => 'Watch a whole series: 30 episodes, no expiry.',
                'features' => ['Unlock 30 episodes', 'Enough for a full series', 'Never expires']],
        ];
        foreach ($packs as $p) {
            $row = [
                'type' => 'episodes', 'currency' => 'TZS', 'price' => $p['price'], 'episode_quota' => $p['episode_quota'],
                'duration_days' => null, 'coins' => null, 'bonus_coins' => null,
                'description' => $p['description'], 'features' => json_encode($p['features']),
                'is_popular' => $p['is_popular'] ?? false, 'is_active' => true, 'sort_order' => $p['sort_order'], 'updated_at' => now(),
            ];
            if (DB::table('plans')->where('name', $p['name'])->exists()) {
                DB::table('plans')->where('name', $p['name'])->update($row);
            } else {
                DB::table('plans')->insert($row + ['name' => $p['name'], 'created_at' => now()]);
            }
        }
    }

    public function down(): void
    {
        DB::table('plans')->whereIn('name', ['7 Episodes', 'Full Series (30 Episodes)'])->update(['is_active' => false]);
        DB::table('plans')->whereIn('name', ['6 Episodes', '15 Episodes'])->update(['is_active' => true]);
    }
};
