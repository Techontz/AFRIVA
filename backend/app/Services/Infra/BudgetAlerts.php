<?php

namespace App\Services\Infra;

use App\Mail\InfraBudgetAlert;
use App\Models\Setting;
use Illuminate\Support\Facades\Mail;

/**
 * Budget threshold emails (php artisan infra:check-budget, hourly). One email per threshold per calendar month:
 * the thresholds already alerted are stored in the settings table (key infra_budget_alerts, hidden from the
 * admin settings form) so a cache flush or a restart never re-sends them. When several thresholds are crossed
 * at once, one email names the highest and the lower ones are marked as sent too.
 */
class BudgetAlerts
{
    public const STATE_KEY = 'infra_budget_alerts';

    /** @return array<int,int> */
    public static function thresholds(): array
    {
        $t = array_map('intval', (array) config('infra.budget_thresholds', [50, 75, 90, 100]));
        sort($t);

        return $t;
    }

    public static function recipient(): ?string
    {
        $email = config('infra.alert_email') ?: Setting::get('support_email');

        return filter_var($email, FILTER_VALIDATE_EMAIL) ? (string) $email : null;
    }

    /** @return array<int,int> */
    public static function sentThisMonth(): array
    {
        $state = json_decode((string) Setting::where('key', self::STATE_KEY)->value('value'), true);
        if (! is_array($state) || ($state['month'] ?? null) !== now()->format('Y-m')) {
            return [];
        }

        return array_values(array_map('intval', (array) ($state['sent'] ?? [])));
    }

    /**
     * @param  array<string,mixed>  $snapshot  InfraMetrics::snapshot()
     * @return array{status:string,percent:?float,threshold:?int}
     */
    public function check(array $snapshot): array
    {
        $budget = $snapshot['budget'] ?? [];
        $percent = $budget['percent'] ?? null;
        if (empty($budget['monthly_budget_usd']) || $percent === null) {
            return ['status' => 'no_budget', 'percent' => null, 'threshold' => null];
        }

        $sent = self::sentThisMonth();
        $crossed = array_values(array_filter(self::thresholds(), fn (int $t) => $percent >= $t));
        $new = array_values(array_diff($crossed, $sent));
        if (! $new) {
            return ['status' => 'nothing_new', 'percent' => $percent, 'threshold' => null];
        }

        $recipient = self::recipient();
        if (! $recipient) {
            return ['status' => 'no_recipient', 'percent' => $percent, 'threshold' => max($new)];
        }

        $threshold = max($new);
        Mail::to($recipient)->send(new InfraBudgetAlert($threshold, (float) $percent, $budget, $snapshot['cost'] ?? []));

        Setting::put(self::STATE_KEY, json_encode([
            'month' => now()->format('Y-m'),
            'sent' => array_values(array_unique(array_merge($sent, $crossed))),
        ]));

        return ['status' => 'sent', 'percent' => $percent, 'threshold' => $threshold];
    }
}
