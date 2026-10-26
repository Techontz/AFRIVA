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
