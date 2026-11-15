<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

class ErrorAlert extends Mailable
{
    use Queueable;

    /** @param array<string,string|int|null> $details */
    public function __construct(public string $exceptionClass, public array $details) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: sprintf('[%s %s] %s', config('app.name'), app()->environment(), class_basename($this->exceptionClass)));
    }

    public function content(): Content
    {
        $rows = '';
        foreach ($this->details as $k => $v) {
            $rows .= '<tr><th align="left">'.e($k).'</th><td><code>'.e((string) $v).'</code></td></tr>';
        }
        $minutes = (int) config('infra.error_alert_throttle_minutes', 10);

        return new Content(htmlString: '<p>An unhandled error was reported. Full details are in the server log.</p>'
            .'<table cellpadding="4">'.$rows.'</table>'
            ."<p>At most one email per error type every {$minutes} minutes.</p>");
    }
}
