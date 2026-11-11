<?php

namespace App\Payments\Gateways;

/**
 * Mixx by Yas (Tigo Pesa) driver — NOT CONNECTED YET.
 * Credentials come from config('payments.drivers.*') which reads .env.
 * When integrating: implement initiate() (push USSD / build redirect), verify() and handleCallback().
 */
class TigoPesaGateway extends NotConnectedGateway
{
    public function name(): string
    {
        return 'Mixx by Yas (Tigo Pesa)';
    }

    protected function nextAction(): string
    {
        return 'await_ussd';
    }
}
