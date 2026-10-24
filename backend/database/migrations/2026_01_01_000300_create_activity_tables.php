<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('watch_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->foreignId('episode_id')->nullable()->constrained()->nullOnDelete();
            $table->integer('progress_seconds')->default(0);
            $table->timestamps();
            $table->unique(['user_id', 'drama_id']);
        });

        Schema::create('episode_views', function (Blueprint $table) {
            $table->id();
            $table->foreignId('episode_id')->constrained()->cascadeOnDelete();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->date('viewed_on')->index();
            $table->timestamps();
            $table->index(['company_id', 'viewed_on']);
            $table->index(['drama_id', 'viewed_on']);
        });

        Schema::create('favorites', function (Blueprint $table) {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->timestamps();
            $table->primary(['user_id', 'drama_id']);
        });

        Schema::create('company_earnings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('drama_id')->nullable()->constrained()->nullOnDelete();
            $table->string('source', 30); // subscription_pool|episode_pack|coins
            $table->unsignedBigInteger('amount');
            $table->date('period_date')->index();
            $table->json('meta')->nullable();
            $table->timestamps();
            $table->index(['company_id', 'period_date']);
        });

        Schema::create('payouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->unsignedBigInteger('amount');
            $table->string('status', 20)->default('pending');
            $table->string('reference')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });

        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('settings');
        Schema::dropIfExists('payouts');
        Schema::dropIfExists('company_earnings');
        Schema::dropIfExists('favorites');
        Schema::dropIfExists('episode_views');
        Schema::dropIfExists('watch_histories');
    }
};
