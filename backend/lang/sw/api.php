<?php

// Ujumbe wa API kwa Kiswahili. Thamani za `code` hazibadiliki; maandishi haya pekee ndiyo hubadilika.
return [
    // Makosa ya jumla ya HTTP (bootstrap/app.php)
    'unauthenticated' => 'Hujaingia. Tafadhali ingia kwenye akaunti yako.',
    'forbidden' => 'Huruhusiwi kufanya kitendo hiki.',
    'not_found' => 'Hatukupata ulichokuwa unatafuta.',
    'method_not_allowed' => 'Njia hii ya HTTP hairuhusiwi kwa anwani hii.',
    'csrf_mismatch' => 'Muda wa kipindi chako umekwisha. Tafadhali onyesha upya ukurasa kisha ujaribu tena.',
    'too_many_requests' => 'Maombi ni mengi mno. Tafadhali punguza kasi na ujaribu tena baada ya muda mfupi.',
    'service_unavailable' => 'Huduma haipatikani kwa sasa. Tafadhali jaribu tena baada ya muda mfupi.',
    'http_error' => 'Hitilafu ya HTTP.',
    'server_error' => 'Hitilafu ya seva. Tafadhali jaribu tena baadaye.',

    // Kuingia na majukumu
    'invalid_credentials' => 'Taarifa hizi za kuingia hazilingani na kumbukumbu zetu.',
    'account_suspended' => 'Akaunti yako imesimamishwa.',
    'account_pending' => 'Ombi lako la kupost linasubiri kukaguliwa. Utaweza kupost likishaidhinishwa.',
    'studio_application_received' => 'Ombi limepokelewa. Sasa pakia video zako 10 za mfano ili tulikague.',
    'account_rejected' => 'Ombi lako la kupost kwenye Afriva halikukubaliwa. Wasiliana nasi kama unaona ni kosa.',
    'account_rejected_reason' => 'Ombi lako la kupost kwenye Afriva halikukubaliwa. Sababu: :reason',
    'creator_already_studio' => 'Akaunti hii tayari ina studio.',
    'creator_application_exists' => 'Tayari una ombi linalosubiri kukaguliwa.',
    'creator_email_taken' => 'Barua pepe hii ni ya akaunti isiyoweza kutuma ombi. Tumia barua pepe nyingine.',
    'creator_password_mismatch' => 'Barua pepe hii tayari ina akaunti ya Afriva. Weka nenosiri la akaunti hiyo ili kuendelea.',
    'creator_id_required' => 'Weka namba ya kitambulisho au pakia picha ya kitambulisho chako.',
    'creator_guidelines_required' => 'Lazima ukubali miongozo ya watayarishi wa Afriva.',
    'application_closed' => 'Ombi hili tayari limekaguliwa.',
    'samples_full' => 'Tayari una video 10 za mfano. Futa moja ili kuibadilisha.',
    'samples_incomplete' => 'Ombi hili linahitaji video 10 za mfano zilizo tayari, za dakika 1 hadi 3, kabla ya kuidhinishwa.',
    'company_not_approved' => 'Studio yako bado haijaidhinishwa. Utaweza kupost Afriva ikishaidhinisha ombi lako.',
    'no_permission' => 'Huna ruhusa ya kufikia sehemu hii.',
    'no_company' => 'Akaunti hii haijaunganishwa na kampuni yoyote.',
    'logged_out' => 'Umetoka kwenye akaunti.',

    // Sehemu (episodes)
    'episode_locked' => 'Sehemu hii imefungwa. Jiunge na VIP au ifungue kwa sarafu.',
    'episode_locked_guest' => 'Sehemu hii imefungwa. Ingia kwenye akaunti, kisha jiunge na VIP au ifungue kwa sarafu.',
    'insufficient_coins' => 'Huna sarafu za kutosha kufungua sehemu hii.',
    'no_episode_pack' => 'Huna kifurushi cha sehemu kinachotumika.',
    'episode_number_taken' => 'Sehemu ya :number tayari ipo kwenye tamthilia hii.',

    // Msimamizi
    'category_slug_taken' => 'Tayari kuna kategoria yenye kitambulisho hiki.',

    // Upakiaji wa video (Bunny Stream)
    'video_storage_not_configured' => 'Upakiaji wa video haupatikani kwa sasa. Tafadhali weka kiungo cha video badala yake.',
    'video_storage_error' => 'Huduma ya video haipatikani. Tafadhali jaribu tena baada ya muda mfupi.',
    'no_video_upload' => 'Sehemu hii haina upakiaji wa video unaoendelea. Anza upakiaji mpya kwanza.',
    'video_upload_mismatch' => 'Upakiaji huu si wa sasa tena kwa sehemu hii. Anza upakiaji mpya.',
];
