<?php

namespace App\Payments\Gateways;

/**
 * Airtel Money driver: NOT CONNECTED YET.
 * Credentials come from config('payments.drivers.*') which reads .env.
 * When integrating: implement initiate() (push USSD / build redirect), verify() and handleCallback().
 */
class AirtelMoneyGateway extends NotConnectedGateway
{
    public function name(): string
    {
        return 'Airtel Money';
    }

    protected function nextAction(): string
    {
        return 'await_ussd';
    }
}
