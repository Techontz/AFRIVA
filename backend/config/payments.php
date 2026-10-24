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
use App\Payments\Gateways\TigoPesaGateway;

return [

    'sandbox' => [
        'auto_approve' => (bool) env('PAYMENTS_SANDBOX_AUTO_APPROVE', false),
    ],

    'callback_base_url' => env('PAYMENTS_CALLBACK_URL', env('APP_URL').'/api/v1/payments/callback'),

    // payment method code => driver key
    'methods' => [
        'mpesa' => 'mpesa',
        'tigopesa' => 'tigopesa',
        'airtelmoney' => 'airtelmoney',
        'halopesa' => 'halopesa',
        'tpesa' => 'bank',      // T-Pesa (TTCL) — routed through the generic aggregator driver until a direct API is chosen
        'visa' => 'card',
        'mastercard' => 'card',
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
    ],
];
