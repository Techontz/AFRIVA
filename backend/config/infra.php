<?php

/*
| Infrastructure dashboard and budget alerts (admin > Infrastructure, php artisan infra:check-budget).
|
| Every provider is optional and only queried when its env token is set. All UNIT PRICES BELOW ARE EDITABLE
| ESTIMATES taken from public price lists on 2026-11-15; they are not invoices. Check each provider's pricing
| page and edit them here when prices change. Lines the dashboard shows are tagged:
|   live_usage = measured right now from the provider or this server
|   estimate   = usage multiplied by the unit prices below, or a list price
|   billed     = an amount the provider's billing API reports as charged
*/

return [

    // How long each provider's figures are cached (seconds). Provider APIs are not called more often than this.
    'cache_ttl' => (int) env('INFRA_CACHE_TTL', 600),

    // HTTP timeout per provider call (seconds).
    'http_timeout' => (int) env('INFRA_HTTP_TIMEOUT', 8),

    // Monthly budget in USD. The admin Settings value "infra_monthly_budget_usd" overrides this when filled.
    'monthly_budget_usd' => env('INFRA_MONTHLY_BUDGET_USD'),

    // Budget alert thresholds in percent. One email per threshold per calendar month.
    'budget_thresholds' => [50, 75, 90, 100],

    // Who gets budget and error alerts. Empty = the support_email setting (budget alerts only).
    'alert_email' => env('INFRA_ALERT_EMAIL'),

    // Error alert emails: at most one per exception class per this many minutes.
    'error_alert_throttle_minutes' => (int) env('INFRA_ERROR_ALERT_THROTTLE_MINUTES', 10),
    'error_alerts' => (bool) env('INFRA_ERROR_ALERTS', true),

    // Editable estimate: EUR to USD conversion for Hetzner prices.
    'eur_to_usd' => (float) env('INFRA_EUR_TO_USD', 1.08),

    'hetzner' => [
        'token' => env('HETZNER_API_TOKEN'),
        'server_id' => env('HETZNER_SERVER_ID'),
        // Used when the API is not connected: CX33 list price incl. IPv4, EUR per month excl. VAT (estimate).
        'fallback_monthly_eur' => (float) env('INFRA_HETZNER_MONTHLY_EUR', 8.99),
        // Automatic backups cost this share of the server price when enabled (Hetzner list price: 20%).
        'backup_percent' => 20.0,
        'backups_enabled' => (bool) env('INFRA_HETZNER_BACKUPS', true),
    ],

    'bunny' => [
        // Account API key (bunny.net > Account settings > API). Needed for storage, bandwidth and billing.
        // The Stream library key (BUNNY_STREAM_API_KEY) alone only gives the video count.
        'account_api_key' => env('BUNNY_ACCOUNT_API_KEY'),
        // Editable estimates in USD (bunny.net Stream pricing, standard network).
        'storage_usd_per_gb' => (float) env('INFRA_BUNNY_STORAGE_USD_PER_GB', 0.01),
        'storage_regions' => (int) env('INFRA_BUNNY_STORAGE_REGIONS', 1),
        // Afriva's audience is mostly in Africa: the Middle East and Africa rate.
        'bandwidth_usd_per_gb' => (float) env('INFRA_BUNNY_BANDWIDTH_USD_PER_GB', 0.06),
        'monthly_minimum_usd' => 1.0,
    ],

    'r2' => [
        'api_token' => env('CLOUDFLARE_API_TOKEN'),
        'account_id' => env('CLOUDFLARE_ACCOUNT_ID'),
        // Buckets to report per bucket (the public and private media buckets plus an optional backup bucket).
        'buckets' => array_values(array_filter([
            env('R2_PUBLIC_BUCKET'), env('R2_PRIVATE_BUCKET'), env('R2_BACKUP_BUCKET'),
        ])),
        // Editable estimates in USD (developers.cloudflare.com/r2/pricing, Standard storage). Egress is free.
        'storage_usd_per_gb_month' => 0.015,
        'class_a_usd_per_million' => 4.50,
        'class_b_usd_per_million' => 0.36,
        'free_storage_gb' => 10,
        'free_class_a_millions' => 1,
        'free_class_b_millions' => 10,
    ],

    // Fixed monthly items with no usage API (editable estimates, USD).
    'fixed' => [
        'vercel' => (float) env('INFRA_VERCEL_MONTHLY_USD', 20),
        'cloudflare' => 0.0,
    ],
];
