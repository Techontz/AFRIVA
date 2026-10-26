<?php

namespace App\Payments\Gateways;

use App\Models\Payment;
use App\Payments\Contracts\PaymentGateway;
use App\Payments\GatewayResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Base for real-provider drivers that are not integrated yet.
 * Replace initiate/verify/handleCallback in the concrete driver when connecting the provider.
 */
abstract class NotConnectedGateway implements PaymentGateway
{
    /** @param array<string,mixed> $config driver config from config/payments.php (+ payment_methods.config) */
    public function __construct(protected array $config = []) {}

    abstract public function name(): string;

    /** await_ussd for mobile money, redirect for card/bank once connected. */
    protected function nextAction(): string
    {
        return 'none';
    }

    public function initiate(Payment $payment, array $data): GatewayResponse
    {
        Log::info("[payments] {$this->name()} initiate called for {$payment->reference}, provider not yet connected.");

        return GatewayResponse::pending('Provider not yet connected');
    }

    public function verify(Payment $payment): GatewayResponse
    {
        return GatewayResponse::pending('Provider not yet connected');
    }

    public function handleCallback(Request $request): ?Payment
    {
        Log::warning("[payments] {$this->name()} callback received but provider not yet connected.", $request->all());

        return null;
    }
}
