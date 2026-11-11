<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('episodes', function (Blueprint $table) {
            // portrait = vertical 9:16 short-drama video, landscape = horizontal 16:9 (chosen by the uploader).
            $table->string('orientation', 10)->default('portrait')->after('duration_seconds');
        });
    }

    public function down(): void
    {
        Schema::table('episodes', function (Blueprint $table) {
            $table->dropColumn('orientation');
        });
    }
};
