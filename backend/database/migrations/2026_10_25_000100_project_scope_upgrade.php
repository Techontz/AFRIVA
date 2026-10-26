<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * AFRIVA Project Scope 2026: creator review workflow, publishing rules, staff roles + audit log,
 * video processing, coin ledger, refunds/fees/receipts, playback analytics and operating costs.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Staff role for role = super_admin: owner|editor|reviewer|finance (null = owner).
            $table->string('staff_role', 20)->nullable()->after('role');
        });

        Schema::table('companies', function (Blueprint $table) {
            $table->timestamp('agreement_accepted_at')->nullable();
            $table->string('agreement_version', 30)->nullable();
        });

        Schema::table('dramas', function (Blueprint $table) {
            $table->string('trailer_url', 1000)->nullable();
            $table->string('age_rating', 10)->nullable();
            // coins_or_vip | vip_only | coins_only
            $table->string('access_mode', 20)->default('coins_or_vip');
            $table->timestamp('publish_at')->nullable()->index();
            // draft | submitted | in_review | changes_requested | approved | rejected
            $table->string('review_status', 30)->default('draft')->index();
            $table->text('review_notes')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('rights_declared_at')->nullable();
        });

        Schema::table('episodes', function (Blueprint $table) {
            $table->string('review_status', 30)->default('draft')->index();
            $table->text('review_notes')->nullable();
            $table->timestamp('playback_verified_at')->nullable();
            // uploaded | processing | ready | failed
            $table->string('video_status', 20)->default('ready');
            $table->text('video_error')->nullable();
            $table->string('hls_path')->nullable();
            $table->json('renditions')->nullable();
            $table->string('subtitle_url', 1000)->nullable();
            $table->unsignedBigInteger('source_size')->nullable();
        });

        Schema::create('content_reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->foreignId('episode_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('action', 30);
            $table->string('from_status', 30)->nullable();
            $table->string('to_status', 30)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['drama_id', 'created_at']);
        });

        Schema::create('content_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->foreignId('episode_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('reason', 30); // copyright|inappropriate|misleading|other
            $table->text('details')->nullable();
            $table->string('contact')->nullable();
            $table->string('status', 20)->default('open')->index(); // open|resolved|dismissed
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('resolution_notes')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('action', 60)->index();
            $table->string('subject_type', 60)->nullable();
            $table->unsignedBigInteger('subject_id')->nullable();
            $table->string('summary')->nullable();
            $table->json('changes')->nullable();
            $table->string('ip', 45)->nullable();
            $table->timestamps();
            $table->index(['subject_type', 'subject_id']);
        });

        Schema::create('coin_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->integer('amount'); // + credit, - debit
            $table->integer('balance_after');
            $table->string('type', 20)->index(); // purchase|bonus|unlock|admin_adjust|refund
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('episode_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('description')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'created_at']);
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->string('idempotency_key', 80)->nullable();
            $table->unsignedBigInteger('fee_amount')->default(0);
            $table->unsignedBigInteger('refunded_amount')->default(0);
            $table->timestamp('refunded_at')->nullable();
            $table->string('receipt_number', 40)->nullable()->unique();
            $table->unique(['user_id', 'idempotency_key']);
        });

        Schema::create('refunds', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payment_id')->constrained()->cascadeOnDelete();
            $table->unsignedBigInteger('amount');
            $table->string('reason')->nullable();
            $table->string('status', 20)->default('completed');
            $table->string('provider_reference')->nullable();
            $table->foreignId('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::table('payment_methods', function (Blueprint $table) {
            $table->decimal('fee_percent', 5, 2)->default(0);
            $table->timestamp('tested_at')->nullable();
        });

        Schema::table('company_earnings', function (Blueprint $table) {
            $table->foreignId('episode_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('gross_amount')->default(0);
        });

        Schema::create('watch_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('session_key', 64)->unique();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('device_id', 64)->nullable();
            // "u:<user id>" or "d:<device id>": one key per viewer for unique counts.
            $table->string('actor_key', 80)->index();
            $table->foreignId('episode_id')->constrained()->cascadeOnDelete();
            $table->foreignId('drama_id')->constrained()->cascadeOnDelete();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->date('watched_on')->index();
            $table->unsignedInteger('watch_seconds')->default(0);
            $table->unsignedInteger('max_position')->default(0);
            $table->unsignedInteger('duration_seconds')->default(0);
            $table->boolean('completed')->default(false);
            $table->unsignedInteger('errors')->default(0);
            $table->string('last_quality', 10)->nullable();
            $table->timestamps();
            $table->index(['drama_id', 'watched_on']);
            $table->index(['episode_id', 'watched_on']);
        });

        Schema::create('active_users', function (Blueprint $table) {
            $table->date('active_on');
            $table->string('actor_key', 80);
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->primary(['active_on', 'actor_key']);
        });

        Schema::create('operating_costs', function (Blueprint $table) {
            $table->id();
            $table->date('period'); // first day of the month
            $table->string('category', 30); // streaming|storage|hosting|payments|other
            $table->unsignedBigInteger('amount');
            $table->string('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index('period');
        });

        // Existing catalogue predates the review workflow: anything already live counts as approved.
        DB::table('dramas')->where('status', 'published')->update(['review_status' => 'approved']);
        DB::table('episodes')->whereIn('drama_id', DB::table('dramas')->where('status', 'published')->select('id'))
            ->update(['review_status' => 'approved', 'playback_verified_at' => now()]);
        DB::table('users')->where('role', 'super_admin')->whereNull('staff_role')->update(['staff_role' => 'owner']);

        // Swahili categories (scope §03). Old English categories without dramas are removed.
        $categories = ['Mapenzi', 'Historia', 'Siri na Mafumbo', 'Vita na Mashujaa', 'Vichekesho', 'Upelelezi', 'Maisha', 'Hadithi za Afrika'];
        $now = now();
        foreach ($categories as $i => $name) {
            $slug = Str::slug($name);
            DB::table('categories')->updateOrInsert(['slug' => $slug], ['name' => $name, 'sort_order' => $i + 1, 'updated_at' => $now, 'created_at' => $now]);
        }
        $swSlugs = array_map(fn ($n) => Str::slug($n), $categories);
        DB::table('categories')->whereNotIn('slug', $swSlugs)
            ->whereNotIn('id', DB::table('category_drama')->select('category_id'))->delete();

        // Launch payment methods: Tanzanian mobile money + international cards. Banks/T-Pesa stay off until a provider is chosen.
        DB::table('payment_methods')->whereIn('code', ['tpesa', 'crdb', 'nmb', 'nbc'])->where('is_integrated', false)->update(['is_enabled' => false]);
    }

    public function down(): void
    {
        Schema::dropIfExists('operating_costs');
        Schema::dropIfExists('active_users');
        Schema::dropIfExists('watch_sessions');
        Schema::table('company_earnings', function (Blueprint $table) {
            $table->dropConstrainedForeignId('episode_id');
            $table->dropColumn('gross_amount');
        });
        Schema::table('payment_methods', fn (Blueprint $t) => $t->dropColumn(['fee_percent', 'tested_at']));
        Schema::dropIfExists('refunds');
        Schema::table('payments', function (Blueprint $table) {
            $table->dropUnique(['user_id', 'idempotency_key']);
            $table->dropUnique(['receipt_number']);
            $table->dropColumn(['idempotency_key', 'fee_amount', 'refunded_amount', 'refunded_at', 'receipt_number']);
        });
        Schema::dropIfExists('coin_transactions');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('content_reports');
        Schema::dropIfExists('content_reviews');
        Schema::table('episodes', fn (Blueprint $t) => $t->dropColumn([
            'review_status', 'review_notes', 'playback_verified_at', 'video_status', 'video_error', 'hls_path', 'renditions', 'subtitle_url', 'source_size',
        ]));
        Schema::table('dramas', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reviewed_by');
            $table->dropColumn(['trailer_url', 'age_rating', 'access_mode', 'publish_at', 'review_status', 'review_notes', 'submitted_at', 'reviewed_at', 'rights_declared_at']);
        });
        Schema::table('companies', fn (Blueprint $t) => $t->dropColumn(['agreement_accepted_at', 'agreement_version']));
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('staff_role'));
    }
};
