<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

/**
 * Renders as { message, code, ...extra } with the given HTTP status.
 */
class ApiException extends RuntimeException
{
    /** @param array<string,mixed> $extra */
    public function __construct(
        string $message,
        public readonly string $errorCode,
        public readonly int $status = 400,
        public readonly array $extra = [],
    ) {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return response()->json(array_merge([
            'message' => $this->getMessage(),
            'code' => $this->errorCode,
        ], $this->extra), $this->status);
    }
}
