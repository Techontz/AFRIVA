<?php

namespace App\Payments\Contracts;

use App\Models\Payment;
use App\Payments\GatewayResponse;
use Illuminate\Http\Request;

interface PaymentGateway
{
    /** Start a payment (push USSD / produce redirect url). */
    public function initiate(Payment $payment, array $data): GatewayResponse;

    /** Ask the provider for the latest status of a payment. */
    public function verify(Payment $payment): GatewayResponse;

    /** Handle a provider webhook; returns the affected payment (status already updated) or null. */
    public function handleCallback(Request $request): ?Payment;
}
