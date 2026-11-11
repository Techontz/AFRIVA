<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    | Bunny Stream (episode videos). Uploads go straight from the browser/app to Bunny over TUS with a
    | short lived signature; the API key never leaves the server. Disabled unless library id, API key and
    | CDN hostname are all set. token_auth_key is the library's CDN token authentication key: when it is
    | empty, playback URLs are returned unsigned.
    */
    'bunny' => [
        'library_id' => env('BUNNY_STREAM_LIBRARY_ID'),
        'api_key' => env('BUNNY_STREAM_API_KEY'),
        'cdn_hostname' => env('BUNNY_STREAM_CDN_HOSTNAME'),
        'token_auth_key' => env('BUNNY_STREAM_TOKEN_KEY'),
        'token_ttl' => (int) env('BUNNY_STREAM_TOKEN_TTL', 14400),
        // Optional: the library's Read-Only API key. When set, webhooks must carry a valid X-BunnyStream-Signature.
        'webhook_secret' => env('BUNNY_STREAM_WEBHOOK_SECRET'),
        // Videos shared by many episodes (e.g. the showcase sample): never deleted when an episode or drama goes.
        // Bunny video id played by every showcase demo episode (database/seeders/ShowcaseSeeder.php).
        // Optional pull zone in front of this API's public files (posters, uploads), e.g. https://afriva-media.b-cdn.net.
        'media_cdn_url' => env('MEDIA_CDN_URL'),
        'showcase_video' => env('BUNNY_STREAM_SHOWCASE_VIDEO'),
        'protected_videos' => array_values(array_filter(array_map('trim', explode(',', (string) env('BUNNY_STREAM_PROTECTED_VIDEOS', ''))))),
        'enabled' => filled(env('BUNNY_STREAM_LIBRARY_ID')) && filled(env('BUNNY_STREAM_API_KEY')) && filled(env('BUNNY_STREAM_CDN_HOSTNAME')),
    ],

];
