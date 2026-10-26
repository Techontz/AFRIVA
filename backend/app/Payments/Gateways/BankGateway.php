<?php

namespace App\Payments\Gateways;

/**
 * Bank / aggregator (CRDB, NMB, NBC, T-Pesa) driver: NOT CONNECTED YET.
 * Credentials come from config('payments.drivers.*') which reads .env.
 * When integrating: implement initiate() (push USSD / build redirect), verify() and handleCallback().
 */
class BankGateway extends NotConnectedGateway
{
    public function name(): string
    {
        return 'Bank / aggregator (CRDB, NMB, NBC, T-Pesa)';
    }

    protected function nextAction(): string
    {
        return 'redirect';
    }
}
