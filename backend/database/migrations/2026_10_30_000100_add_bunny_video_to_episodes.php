<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Bunny Stream video per episode.
 * video_status: none | uploading | processing | ready | failed
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('episodes', function (Blueprint $table) {
            $table->string('bunny_video_id')->nullable()->index();
            $table->string('video_status')->default('none');
            $table->index(['video_status', 'updated_at'], 'episodes_video_status_updated_at_index');
        });

        DB::table('episodes')->whereNotNull('video_url')->where('video_url', '!=', '')->update(['video_status' => 'ready']);
    }

    public function down(): void
    {
        Schema::table('episodes', function (Blueprint $table) {
            $table->dropIndex('episodes_video_status_updated_at_index');
            $table->dropIndex(['bunny_video_id']);
            $table->dropColumn(['bunny_video_id', 'video_status']);
        });
    }
};
