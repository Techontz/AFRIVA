<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    // One "card" method for the provider's hosted card page (Visa and Mastercard on the same page).
    public function up(): void
    {
        if (! DB::table('payment_methods')->where('code', 'card')->exists()) {
            DB::table('payment_methods')->insert([
                'code' => 'card', 'name' => 'Visa / Mastercard', 'type' => 'card', 'is_enabled' => true,
                'is_integrated' => false, 'sort_order' => 60, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('payment_methods')->where('code', 'card')->whereNotIn('code', DB::table('payments')->select('payment_method_code'))->delete();
    }
};
