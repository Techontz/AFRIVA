<?php

/*
| Afriva uses bearer tokens (no cookies), so credentials are not needed.
| The Next.js web app runs on http://localhost:3000; Flutter (incl. Flutter web on random
| localhost ports) is allowed via the localhost pattern. Native mobile apps are not subject to CORS.
| Add production origins with CORS_ALLOWED_ORIGINS (comma separated).
*/

return [

    'paths' => ['api/*', 'storage/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_values(array_filter(array_map('trim', explode(',', (string) env(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost:3000,http://127.0.0.1:3000'
    ))))),

    'allowed_origins_patterns' => [
        '#^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$#',
    ],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 3600,

    'supports_credentials' => false,

];
