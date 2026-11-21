<?php

/*
|--------------------------------------------------------------------------
| Afriva payment gateways
|--------------------------------------------------------------------------
| Every payment method code (payment_methods.code) maps to a driver class.
| None of the real providers are connected yet: their drivers return
| GatewayResponse::pending('Provider not yet connected').
|
| While PAYMENTS_SANDBOX_AUTO_APPROVE=true, any method that is NOT flagged
| `is_integrated` in the payment_methods table is routed to the SandboxGateway,
| which approves the payment immediately so the whole flow can be demoed.
*/

use App\Payments\Gateways\AirtelMoneyGateway;
use App\Payments\Gateways\BankGateway;
use App\Payments\Gateways\CardGateway;
use App\Payments\Gateways\HaloPesaGateway;
use App\Payments\Gateways\MpesaGateway;
use App\Payments\Gateways\SandboxGateway;
use App\Payments\Gateways\SnippeGateway;

// When a Snippe API key is set, every mobile money network and cards go through Snippe.
$snippe = filled(env('SNIPPE_API_KEY'));
use App\Payments\Gateways\TigoPesaGateway;

return [

    'sandbox' => [
        'auto_approve' => (bool) env('PAYMENTS_SANDBOX_AUTO_APPROVE', false),
        // POST /payments/callback/sandbox can approve a pending sandbox payment by reference.
        // It is unauthenticated, so it is off in production unless explicitly enabled.
        'callbacks' => (bool) env('PAYMENTS_SANDBOX_CALLBACKS', env('APP_ENV', 'production') !== 'production'),
    ],

    // Where Snippe's hosted card page sends the viewer back (a ?payment=REF query is appended).
    'return_url' => env('PAYMENTS_RETURN_URL', 'https://afriva.co.tz/vip'),

    'callback_base_url' => env('PAYMENTS_CALLBACK_URL', env('APP_URL').'/api/v1/payments/callback'),

    // payment method code => driver key
    'methods' => [
        'mpesa' => $snippe ? 'snippe' : 'mpesa',
        'tigopesa' => $snippe ? 'snippe' : 'tigopesa',
        'airtelmoney' => $snippe ? 'snippe' : 'airtelmoney',
        'halopesa' => $snippe ? 'snippe' : 'halopesa',
        'tpesa' => 'bank',      // T-Pesa (TTCL) — routed through the generic aggregator driver until a direct API is chosen
        'visa' => $snippe ? 'snippe' : 'card',
        'mastercard' => $snippe ? 'snippe' : 'card',
        'card' => $snippe ? 'snippe' : 'card', // hosted card page (any Visa or Mastercard)
        'crdb' => 'bank',
        'nmb' => 'bank',
        'nbc' => 'bank',
        'sandbox' => 'sandbox',
    ],

    'drivers' => [
        'mpesa' => [
            'class' => MpesaGateway::class,
            'api_key' => env('MPESA_API_KEY'),
            'public_key' => env('MPESA_PUBLIC_KEY'),
            'service_provider_code' => env('MPESA_SERVICE_PROVIDER_CODE'),
            'base_url' => env('MPESA_BASE_URL', 'https://openapi.m-pesa.com/sandbox'),
        ],
        'tigopesa' => [
            'class' => TigoPesaGateway::class,
            'client_id' => env('TIGOPESA_CLIENT_ID'),
            'client_secret' => env('TIGOPESA_CLIENT_SECRET'),
            'biller_msisdn' => env('TIGOPESA_BILLER_MSISDN'),
            'base_url' => env('TIGOPESA_BASE_URL'),
        ],
        'airtelmoney' => [
            'class' => AirtelMoneyGateway::class,
            'client_id' => env('AIRTEL_CLIENT_ID'),
            'client_secret' => env('AIRTEL_CLIENT_SECRET'),
            'base_url' => env('AIRTEL_BASE_URL', 'https://openapiuat.airtel.africa'),
        ],
        'halopesa' => [
            'class' => HaloPesaGateway::class,
            'api_key' => env('HALOPESA_API_KEY'),
            'merchant_id' => env('HALOPESA_MERCHANT_ID'),
            'base_url' => env('HALOPESA_BASE_URL'),
        ],
        'card' => [
            'class' => CardGateway::class,
            'provider' => env('CARD_PROVIDER', 'dpo'), // dpo|flutterwave|selcom
            'api_key' => env('CARD_API_KEY'),
            'secret_key' => env('CARD_SECRET_KEY'),
            'base_url' => env('CARD_BASE_URL'),
        ],
        'bank' => [
            'class' => BankGateway::class,
            'provider' => env('BANK_PROVIDER', 'selcom'),
            'api_key' => env('BANK_API_KEY'),
            'secret_key' => env('BANK_SECRET_KEY'),
            'base_url' => env('BANK_BASE_URL'),
        ],
        'sandbox' => [
            'class' => SandboxGateway::class,
        ],
        'snippe' => [
            'class' => SnippeGateway::class,
            'api_key' => env('SNIPPE_API_KEY'),
            'webhook_secret' => env('SNIPPE_WEBHOOK_SECRET'),
            'base_url' => env('SNIPPE_BASE_URL', 'https://api.snippe.sh'),
            'api_version' => env('SNIPPE_API_VERSION', '2026-01-25'),
        ],
    ],
];
