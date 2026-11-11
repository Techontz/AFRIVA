<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Indexes for the hot public catalogue queries:
 * - published dramas ordered by views (home rows, rankings, /dramas default sort, related)
 * - published dramas ordered by release date (new releases, sort=newest)
 * - trending: episode_views filtered by viewed_on and grouped by drama_id (covering index)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('dramas', function (Blueprint $table) {
            $table->index(['status', 'views'], 'dramas_status_views_index');
            $table->index(['status', 'release_date'], 'dramas_status_release_date_index');
        });

        Schema::table('episode_views', function (Blueprint $table) {
            $table->index(['viewed_on', 'drama_id'], 'episode_views_viewed_on_drama_id_index');
        });
    }

    public function down(): void
    {
        Schema::table('episode_views', function (Blueprint $table) {
            $table->dropIndex('episode_views_viewed_on_drama_id_index');
        });

        Schema::table('dramas', function (Blueprint $table) {
            $table->dropIndex('dramas_status_release_date_index');
            $table->dropIndex('dramas_status_views_index');
        });
    }
};
