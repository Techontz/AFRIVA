<?php

namespace App\Payments\Gateways;

/**
 * M-Pesa (Vodacom) driver — NOT CONNECTED YET.
 * Credentials come from config('payments.drivers.*') which reads .env.
 * When integrating: implement initiate() (push USSD / build redirect), verify() and handleCallback().
 */
class MpesaGateway extends NotConnectedGateway
{
    public function name(): string
    {
        return 'M-Pesa (Vodacom)';
    }

    protected function nextAction(): string
    {
        return 'await_ussd';
    }
}
