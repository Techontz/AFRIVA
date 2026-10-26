<?php

/*
|--------------------------------------------------------------------------
| Afriva video delivery
|--------------------------------------------------------------------------
| Uploaded episode videos live on the private "videos" disk (never under
| public/storage). Episodes store them as "private:<path>", and the API hands
| out short-lived signed URLs to GET /api/v1/media/videos/<path>.
|
| VIDEO_DELIVERY=php      Laravel streams the file itself (local dev, supports Range).
| VIDEO_DELIVERY=x-accel  Laravel only checks the signature and replies with an
|                         X-Accel-Redirect header; Nginx serves the file from an
|                         internal location (production; see deploy/nginx).
*/

return [
    'video_delivery' => env('VIDEO_DELIVERY', 'php'),

    // Minutes a signed playback URL stays valid.
    'video_url_ttl' => (int) env('VIDEO_URL_TTL_MINUTES', 360),

    // Must match the `internal` location in the Nginx site config.
    'x_accel_prefix' => '/_protected_videos/',

    /*
    | Transcoding (scope §08): uploaded videos are encoded with ffmpeg by a queued job into
    | adaptive HLS (480p / 720p / 1080p, never above the source) plus a thumbnail.
    | MEDIA_TRANSCODE=false keeps the uploaded file as-is (single quality), e.g. without ffmpeg.
    */
    'transcode' => (bool) env('MEDIA_TRANSCODE', false),
    'ffmpeg' => env('FFMPEG_PATH', 'ffmpeg'),
    'ffprobe' => env('FFPROBE_PATH', 'ffprobe'),
    'transcode_timeout' => (int) env('MEDIA_TRANSCODE_TIMEOUT', 3600),
    'hls_segment_seconds' => 6,

    // short side in pixels => video bitrate (kbps)
    'renditions' => [
        480 => 900,
        720 => 2200,
        1080 => 4500,
    ],
];
