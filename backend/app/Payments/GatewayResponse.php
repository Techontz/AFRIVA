<?php

namespace App\Payments;

/**
 * Immutable result of a gateway call.
 */
final class GatewayResponse
{
    public const SUCCESS = 'success';

    public const PENDING = 'pending';

    public const FAILED = 'failed';

    /** @param array<string,mixed> $raw */
    public function __construct(
        public readonly string $status,
        public readonly string $message = '',
        public readonly string $nextAction = 'none', // await_ussd|redirect|none
        public readonly ?string $redirectUrl = null,
        public readonly ?string $providerReference = null,
        public readonly array $raw = [],
    ) {}

    public static function success(string $message = 'Payment successful', ?string $providerReference = null, array $raw = []): self
    {
        return new self(self::SUCCESS, $message, 'none', null, $providerReference, $raw);
    }

    public static function pending(string $message = 'Payment pending', string $nextAction = 'none', ?string $redirectUrl = null, ?string $providerReference = null, array $raw = []): self
    {
        return new self(self::PENDING, $message, $nextAction, $redirectUrl, $providerReference, $raw);
    }

    public static function failed(string $message = 'Payment failed', array $raw = []): self
    {
        return new self(self::FAILED, $message, 'none', null, null, $raw);
    }

    public function isSuccessful(): bool
    {
        return $this->status === self::SUCCESS;
    }

    public function isPending(): bool
    {
        return $this->status === self::PENDING;
    }

    public function isFailed(): bool
    {
        return $this->status === self::FAILED;
    }
}
