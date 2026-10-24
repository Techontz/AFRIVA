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
