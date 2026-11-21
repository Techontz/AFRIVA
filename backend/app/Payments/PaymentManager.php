<?php

namespace App\Payments;

use App\Models\Payment;
use App\Models\PaymentMethod;
use App\Payments\Contracts\PaymentGateway;
use InvalidArgumentException;

/**
 * Resolves the gateway driver for a payment method code (or a provider/driver key for callbacks).
 */
class PaymentManager
{
    /** @var array<string,PaymentGateway> */
    protected array $resolved = [];

    /** Driver to use for a checkout with the given payment method code. */
    public function forMethod(string $methodCode): PaymentGateway
    {
        $method = PaymentMethod::where('code', $methodCode)->first();

        // Demo mode: methods that are not integrated go through the sandbox.
        if (config('payments.sandbox.auto_approve') && (! $method || ! $method->is_integrated)) {
            return $this->driver('sandbox');
        }

        $driverKey = config("payments.methods.{$methodCode}");
        if (! $driverKey) {
            throw new InvalidArgumentException("No payment driver configured for method [{$methodCode}].");
        }

        return $this->driver($driverKey, $method?->config ?? []);
    }

    /** Driver by key (mpesa, tigopesa, airtelmoney, halopesa, card, bank, sandbox) or by method code. */
    public function driver(string $key, array $extraConfig = []): PaymentGateway
    {
        if (! config("payments.drivers.{$key}") && config("payments.methods.{$key}")) {
            $key = config("payments.methods.{$key}");
        }

        $config = config("payments.drivers.{$key}");
        if (! $config || empty($config['class'])) {
            throw new InvalidArgumentException("Unknown payment driver [{$key}].");
        }

        $cacheKey = $key.($extraConfig ? ':'.md5(json_encode($extraConfig)) : '');

        return $this->resolved[$cacheKey] ??= new $config['class'](array_merge($config, $extraConfig));
    }

    /**
     * Can this method take a real payment right now? True in demo mode, otherwise only when the method is
     * enabled, flagged integrated by the admin, and its driver is actually connected (not a placeholder).
     */
    public function isAvailable(string $methodCode): bool
    {
        $method = PaymentMethod::where('code', $methodCode)->first();
        if (! $method || ! $method->is_enabled) {
            return false;
        }
        if (config('payments.sandbox.auto_approve')) {
            return true;
        }
                if (! config("payments.methods.{$methodCode}")) {
            return false;
        }
        $gateway = $this->forMethod($methodCode);
        if ($gateway instanceof \App\Payments\Gateways\NotConnectedGateway) {
            return false;
        }

        return ! method_exists($gateway, 'isConnected') || $gateway->isConnected();
    }

        /** True when cards for this method are entered on the provider's hosted page (no card details in checkout). */
    public function hostedCards(string $methodCode): bool
    {
        if (config('payments.sandbox.auto_approve')) {
            return false;
        }
        $gateway = $this->forMethod($methodCode);

        return method_exists($gateway, 'hostedCards') && $gateway->hostedCards();
    }

    /** Which driver handled a stored payment (sandbox if it was routed there). */
    public function forPayment(Payment $payment): PaymentGateway
    {
        $driver = $payment->meta['driver'] ?? null;

        return $driver ? $this->driver($driver) : $this->forMethod($payment->payment_method_code);
    }

    public function keyOf(PaymentGateway $gateway): string
    {
        foreach (config('payments.drivers') as $key => $cfg) {
            if ($gateway instanceof $cfg['class']) {
                return $key;
            }
        }

        return 'unknown';
    }
}
