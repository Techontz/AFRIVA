<?php

namespace App\Payments\Gateways;

/**
 * HaloPesa driver: NOT CONNECTED YET.
 * Credentials come from config('payments.drivers.*') which reads .env.
 * When integrating: implement initiate() (push USSD / build redirect), verify() and handleCallback().
 */
class HaloPesaGateway extends NotConnectedGateway
{
    public function name(): string
    {
        return 'HaloPesa';
    }

    protected function nextAction(): string
    {
        return 'await_ussd';
    }
}
