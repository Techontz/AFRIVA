<?php

use App\Models\Subscription;
use Illuminate\Support\Facades\Schedule;

// Pool yesterday's subscription revenue into company_earnings (see SPEC §4 revenue attribution).
Schedule::command('earnings:distribute')->dailyAt('00:30')->withoutOverlapping();

// Mark time-based subscriptions whose window has ended as expired.
Schedule::call(function () {
    Subscription::whereIn('type', ['weekly', 'monthly', 'yearly'])
        ->where('status', 'active')
        ->where('ends_at', '<=', now())
        ->update(['status' => 'expired']);
})->hourly()->name('subscriptions:expire');

// Fallback for missed Bunny Stream webhooks: re-check uploads still uploading/processing (no-op when not configured).
Schedule::command('bunny:sync')->everyFiveMinutes()->withoutOverlapping();

// Infrastructure budget: one email per threshold (50/75/90/100%) per month. No-op without a budget.
Schedule::command('infra:check-budget')->hourly()->withoutOverlapping();
