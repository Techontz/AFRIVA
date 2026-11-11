<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('dramas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained('companies')->cascadeOnDelete();
            $table->string('title');
            $table->string('slug')->unique();
            $table->text('synopsis')->nullable();
            $table->string('poster_url')->nullable();
            $table->string('backdrop_url')->nullable();
            $table->integer('total_episodes')->default(0);
            $table->integer('free_episodes')->default(5);
            $table->integer('coins_per_episode')->default(30);
            $table->string('status', 20)->default('draft')->index();
            $table->boolean('is_featured')->default(false);
            $table->string('badge', 10)->nullable();
            $table->string('language', 20)->default('sw');
            $table->date('release_date')->nullable();
            $table->unsignedBigInteger('views')->default(0);
            $table->timestamps();
        });

        Schema::create('category_drama', function (Blueprint $table) {
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->primary(['category_id', 'drama_id']);
        });

        Schema::create('tags', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->timestamps();
        });

        Schema::create('drama_tag', function (Blueprint $table) {
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tag_id')->constrained()->cascadeOnDelete();
            $table->primary(['drama_id', 'tag_id']);
        });

        Schema::create('episodes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->integer('number');
            $table->string('title')->nullable();
            $table->string('video_url')->nullable();
            $table->string('thumbnail_url')->nullable();
            $table->integer('duration_seconds')->default(0);
            // null = derived (number <= drama.free_episodes); true/false = explicit override
            $table->boolean('is_free')->nullable();
            $table->unsignedBigInteger('views')->default(0);
            $table->timestamps();
            $table->unique(['drama_id', 'number']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('episodes');
        Schema::dropIfExists('drama_tag');
        Schema::dropIfExists('tags');
        Schema::dropIfExists('category_drama');
        Schema::dropIfExists('dramas');
        Schema::dropIfExists('categories');
    }
};
