<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Where the studio's share of revenue is paid (editable by the studio in Studio > Profile).
        Schema::table('companies', function (Blueprint $table) {
            $table->string('payout_method', 20)->nullable()->after('description');      // mobile_money | bank
            $table->string('payout_provider', 30)->nullable()->after('payout_method');  // mpesa | mixx | airtel | halopesa | tpesa
            $table->string('payout_bank_name', 120)->nullable()->after('payout_provider');
            $table->string('payout_account_name', 150)->nullable()->after('payout_bank_name');
            $table->string('payout_account_number', 60)->nullable()->after('payout_account_name');
        });

        // New studios take the admin setting (creator_revenue_share_percent), the DB default only matches its default.
        Schema::table('companies', function (Blueprint $table) {
            $table->decimal('revenue_share_percent', 5, 2)->default(60.00)->change();
        });

        // "Request to post" submissions: identity + guidelines acceptance. Reviewed by super admins.
        Schema::create('studio_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->boolean('existing_user')->default(false); // true: a viewer account becomes the studio owner on approval
            $table->string('full_name', 150);
            $table->string('id_type', 20);                    // nida | passport
            $table->text('id_number')->nullable();            // encrypted at rest
            $table->string('id_document_path')->nullable();   // private disk only
            $table->string('phone', 32);
            $table->timestamp('guidelines_accepted_at');
            $table->decimal('creator_share_percent', 5, 2);   // share shown when the guidelines were accepted
            $table->string('status', 20)->default('pending')->index(); // pending | approved | rejected
            $table->string('rejection_reason', 500)->nullable();      // shown to the applicant
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        // 10 sample videos (about 2 minutes each) uploaded straight to Bunny Stream so the admin can judge quality.
        // Never part of the public catalogue.
        Schema::create('application_samples', function (Blueprint $table) {
            $table->id();
            $table->foreignId('studio_application_id')->constrained('studio_applications')->cascadeOnDelete();
            $table->string('bunny_video_id', 64)->nullable()->unique();
            $table->string('title', 150)->nullable();
            $table->unsignedInteger('duration_seconds')->nullable();
            $table->string('status', 20)->default('uploading')->index(); // uploading | processing | ready | failed
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('application_samples');
        Schema::dropIfExists('studio_applications');
        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn(['payout_method', 'payout_provider', 'payout_bank_name', 'payout_account_name', 'payout_account_number']);
        });
        Schema::table('companies', function (Blueprint $table) {
            $table->decimal('revenue_share_percent', 5, 2)->default(70.00)->change();
        });
    }
};
