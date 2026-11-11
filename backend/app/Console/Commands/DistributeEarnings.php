<?php

namespace App\Console\Commands;

use App\Services\EarningsService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

class DistributeEarnings extends Command
{
    protected $signature = 'earnings:distribute {--date= : Day to distribute (Y-m-d). Defaults to yesterday.}';

    protected $description = "Pool the day's prorated time-subscription revenue and split it across companies by subscriber views";

    public function handle(EarningsService $earnings): int
    {
        $date = $this->option('date') ? Carbon::parse($this->option('date')) : now()->subDay();
        $result = $earnings->distribute($date);

        $this->info(sprintf(
            'Distributed %s: pool %s TZS, %d subscriber views, %d earning rows, %s TZS to companies.',
            $result['date'], number_format($result['pool'], 2), $result['subscriber_views'], $result['rows'], number_format($result['distributed'])
        ));

        return self::SUCCESS;
    }
}
