<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

class InfraBudgetAlert extends Mailable
{
    use Queueable;

    /**
     * @param  array<string,mixed>  $budget
     * @param  array<string,mixed>  $cost
     */
    public function __construct(public int $threshold, public float $percent, public array $budget, public array $cost) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: sprintf('[%s] Infrastructure spend at %s%% of the monthly budget', config('app.name'), $this->threshold));
    }

    public function content(): Content
    {
        $e = fn ($v) => e((string) $v);
        $rows = '';
        foreach ($this->cost['lines'] ?? [] as $line) {
            $amount = $line['amount_usd'] === null ? 'not connected' : 'US$ '.number_format((float) $line['amount_usd'], 2);
            $rows .= '<tr><td>'.$e($line['label']).'</td><td>'.$e($amount).'</td><td>'.$e($line['tag']).'</td></tr>';
        }

        $html = '<p>The <strong>estimated</strong> infrastructure cost for '.$e($this->budget['month'] ?? now()->format('Y-m'))
            .' is US$ '.$e(number_format((float) ($this->budget['estimated_total_usd'] ?? 0), 2))
            .', which is '.$e($this->percent).'% of the monthly budget of US$ '.$e(number_format((float) ($this->budget['monthly_budget_usd'] ?? 0), 2)).'.</p>'
            .'<table cellpadding="4" border="1" style="border-collapse:collapse"><tr><th>Provider</th><th>Monthly</th><th>Type</th></tr>'.$rows.'</table>'
            .'<p>These figures are estimates from live usage and list prices, not invoices. Monitoring does not cap spending: '
            .'Bunny bandwidth keeps being charged while videos are watched. Review the admin Infrastructure page.</p>'
            .'<p>You get one email per threshold (50, 75, 90, 100%) per month.</p>';

        return new Content(htmlString: $html);
    }
}
