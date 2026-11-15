<?php

namespace App\Console\Commands;

use App\Services\Infra\BudgetAlerts;
use App\Services\Infra\InfraMetrics;
use Illuminate\Console\Command;

class CheckInfraBudget extends Command
{
    protected $signature = 'infra:check-budget {--fresh : Ignore cached provider figures}';

    protected $description = 'Email INFRA_ALERT_EMAIL once per month when estimated infrastructure cost crosses 50, 75, 90 or 100% of the budget';

    public function handle(InfraMetrics $metrics, BudgetAlerts $alerts): int
    {
        $result = $alerts->check($metrics->snapshot((bool) $this->option('fresh')));

        $this->line(match ($result['status']) {
            'no_budget' => 'No monthly budget set (INFRA_MONTHLY_BUDGET_USD or the infra_monthly_budget_usd setting).',
            'nothing_new' => "Estimated spend at {$result['percent']}% of budget; no new threshold.",
            'no_recipient' => "Threshold {$result['threshold']}% crossed but no alert email is configured.",
            'sent' => "Alert sent for {$result['threshold']}% (estimated spend at {$result['percent']}%).",
            default => $result['status'],
        });

        return self::SUCCESS;
    }
}
