<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const VALUES = [
        'support_email' => ['support@afriva.com', 'support@afriva.co.tz'],
        'contact_business' => ['business@afriva.com', 'business@afriva.co.tz'],
        'contact_press' => ['press@afriva.com', 'press@afriva.co.tz'],
    ];

    public function up(): void
    {
        foreach (self::VALUES as $key => [$old, $new]) {
            DB::table('settings')->where('key', $key)->where('value', $old)->update(['value' => $new]);
        }
    }

    public function down(): void
    {
        foreach (self::VALUES as $key => [$old, $new]) {
            DB::table('settings')->where('key', $key)->where('value', $new)->update(['value' => $old]);
        }
    }
};
