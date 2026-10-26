<?php

namespace App\Console\Commands;

use App\Models\AuditLog;
use App\Services\AnalyticsService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

/** Cost alerts (scope §08): warn when month-to-date streaming + operating costs approach the configured limit. */
class CheckCosts extends Command
{
    protected $signature = 'costs:check';

    protected $description = 'Log a warning when this month\'s costs reach 80% of cost_alert_monthly_tzs';

    public function handle(AnalyticsService $analytics): int
    {
        foreach ($analytics->costAlerts() as $alert) {
            Log::warning('[costs] '.$alert['message'], $alert);
            AuditLog::create(['action' => 'cost.alert', 'summary' => $alert['message'], 'changes' => $alert]);
            $this->warn($alert['message']);
        }

        return self::SUCCESS;
    }
}
