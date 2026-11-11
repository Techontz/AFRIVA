<?php

namespace App\Payments\Gateways;

/**
 * Card (Visa/Mastercard via DPO/Flutterwave/Selcom) driver — NOT CONNECTED YET.
 * Credentials come from config('payments.drivers.*') which reads .env.
 * When integrating: implement initiate() (push USSD / build redirect), verify() and handleCallback().
 */
class CardGateway extends NotConnectedGateway
{
    public function name(): string
    {
        return 'Card (Visa/Mastercard via DPO/Flutterwave/Selcom)';
    }

    protected function nextAction(): string
    {
        return 'redirect';
    }
}
