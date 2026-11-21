<?php

// Human readable API messages. The machine readable `code` values never change; only these texts do.
return [
    // Generic HTTP errors (bootstrap/app.php)
    'unauthenticated' => 'Unauthenticated.',
    'forbidden' => 'Forbidden.',
    'not_found' => 'Resource not found.',
    'method_not_allowed' => 'This HTTP method is not allowed for this endpoint.',
    'csrf_mismatch' => 'Your session has expired. Please refresh and try again.',
    'too_many_requests' => 'Too many requests. Please slow down and try again shortly.',
    'service_unavailable' => 'The service is temporarily unavailable. Please try again shortly.',
    'http_error' => 'HTTP error.',
    'server_error' => 'Server error.',

    // Auth and roles
    'invalid_credentials' => 'These credentials do not match our records.',
    'google_failed' => 'Google sign-in could not be verified. Please try again.',
    'facebook_failed' => 'Facebook sign-in could not be verified. Please try again.',
    'account_suspended' => 'Your account is suspended.',
    'account_pending' => 'Your request to post is waiting for review. You can post once it is approved.',
    'studio_application_received' => 'Request received. Now upload your 10 sample videos so we can review it.',
    'account_rejected' => 'Your request to post on Afriva was not approved. Contact support if you think this is a mistake.',
    'account_rejected_reason' => 'Your request to post on Afriva was not approved. Reason: :reason',
    'creator_already_studio' => 'This account already has a studio.',
    'creator_application_exists' => 'You already have a request waiting for review.',
    'creator_email_taken' => 'This email already belongs to an account that cannot apply. Use another email.',
    'creator_password_mismatch' => 'This email already has an Afriva account. Enter that account\'s password to continue.',
    'creator_id_required' => 'Enter your ID number or upload a photo of your ID.',
    'creator_guidelines_required' => 'You must accept the Afriva creator guidelines.',
    'application_closed' => 'This request has already been reviewed.',
    'samples_full' => 'You already have 10 sample videos. Delete one to replace it.',
    'samples_incomplete' => 'This request needs 10 ready sample videos of 1 to 3 minutes before it can be approved.',
    'company_not_approved' => 'Your studio is not approved yet. You can post once Afriva approves your request.',
    'no_permission' => 'You do not have permission to access this resource.',
    'no_company' => 'No company is linked to this account.',
    'logged_out' => 'Logged out.',

    // Episodes
    'episode_locked' => 'This episode is locked. Subscribe to VIP or unlock it with coins.',
    'episode_locked_guest' => 'This episode is locked. Log in and subscribe or unlock it with coins.',
    'insufficient_coins' => 'Not enough coins to unlock this episode.',
    'no_episode_pack' => 'You have no active episode pack.',
    'episode_number_taken' => 'Episode :number already exists for this drama.',

    // Admin
    'category_slug_taken' => 'A category with this slug already exists.',

    // Video uploads (Bunny Stream)
    'video_storage_not_configured' => 'Video uploads are not available right now. Please paste a video URL instead.',
    'video_storage_error' => 'The video service could not be reached. Please try again in a moment.',
    'no_video_upload' => 'This episode has no video upload in progress. Start a new upload first.',
    'video_upload_mismatch' => 'This upload is no longer the current one for this episode. Start a new upload.',
];
