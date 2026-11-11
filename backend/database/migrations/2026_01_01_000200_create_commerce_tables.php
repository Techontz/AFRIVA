<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('type', 20)->index(); // weekly|monthly|yearly|episodes|coins
            $table->unsignedBigInteger('price');
            $table->string('currency', 3)->default('TZS');
            $table->integer('duration_days')->nullable();
            $table->integer('episode_quota')->nullable();
            $table->integer('coins')->nullable();
            $table->integer('bonus_coins')->nullable();
            $table->text('description')->nullable();
            $table->json('features')->nullable();
            $table->boolean('is_popular')->default(false);
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('payment_methods', function (Blueprint $table) {
            $table->id();
            $table->string('code', 30)->unique();
            $table->string('name');
            $table->string('type', 20); // mobile_money|card|bank
            $table->string('logo_url')->nullable();
            $table->string('color', 20)->nullable();
            $table->boolean('is_enabled')->default(true);
            $table->boolean('is_integrated')->default(false);
            $table->integer('sort_order')->default(0);
            $table->text('config')->nullable(); // encrypted JSON
            $table->timestamps();
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('plan_id')->nullable()->constrained()->nullOnDelete();
            $table->string('payment_method_code', 30)->index();
            $table->string('reference', 64)->unique();
            $table->unsignedBigInteger('amount');
            $table->string('currency', 3)->default('TZS');
            $table->string('phone', 32)->nullable();
            $table->string('status', 20)->default('pending')->index();
            $table->string('provider_reference')->nullable();
            $table->json('meta')->nullable();
            $table->timestamp('paid_at')->nullable()->index();
            $table->timestamps();
        });

        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('plan_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 20);
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->integer('episodes_remaining')->nullable();
            $table->string('status', 20)->default('active');
            $table->timestamps();
            $table->index(['user_id', 'status']);
        });

        Schema::create('episode_unlocks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('episode_id')->constrained()->cascadeOnDelete();
            $table->string('method', 20); // coins|episode_pack|subscription
            $table->integer('coins_spent')->default(0);
            $table->foreignId('subscription_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();
            $table->unique(['user_id', 'episode_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('episode_unlocks');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('payment_methods');
        Schema::dropIfExists('plans');
    }
};
