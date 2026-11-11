<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A viewer's saved ways to pay. Cards keep only what can be shown (brand, last 4, expiry) and the
        // gateway's token; card numbers and CVCs never reach this API.
        Schema::create('saved_payment_methods', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 20); // mobile_money | card
            $table->string('method_code', 32); // mpesa, airtelmoney, visa, mastercard, ...
            $table->string('phone', 20)->nullable();
            $table->string('card_last4', 4)->nullable();
            $table->unsignedTinyInteger('card_exp_month')->nullable();
            $table->unsignedSmallInteger('card_exp_year')->nullable();
            $table->text('provider_token')->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('saved_payment_methods');
    }
};
