/// Kiswahili UI strings, keyed by the exact English text. See core/i18n.dart.
///
/// Covers the AFRIVA project-scope additions: Creator Studio ("Wasilisha Kazi
/// Yako"), receipts, coin history, help, trailer, report, quality picker and
/// the free/locked episode labels.
const Map<String, String> swCreator = {
  // Home / navigation
  'Hello! What would you like to watch today?': 'Habari! Uangalie nini leo?',
  'Hello {name}! What would you like to watch today?': 'Habari {name}! Uangalie nini leo?',
  'Continue watching': 'Endelea kutazama',
  'Swipe through the first episode of every series': 'Telezesha uone episode ya kwanza ya kila series',
  'Favorite': 'Kipendwa',

  // Series detail
  'Watch trailer': 'Tazama trailer',
  'Trailer': 'Trailer',
  'The trailer could not be played.': 'Trailer imeshindwa kucheza.',
  'Report': 'Ripoti',
  'All ages': 'Wote',
  '{n} min': 'Dakika {n}',
  '{h} h {m} min': 'Saa {h} dakika {m}',
  'Episodes 1-{free} are free': 'Episode 1-{free} ni bure',
  'then {coins} coins per episode or VIP': 'zinazofuata ni coins {coins} kwa episode au VIP',
  'then {coins} coins per episode': 'zinazofuata ni coins {coins} kwa episode',
  'then VIP only': 'zinazofuata ni za VIP pekee',
  'FREE': 'BURE',

  // Report
  'Report "{title}"': 'Ripoti "{title}"',
  'The AFRIVA team reviews every report.': 'Timu ya AFRIVA hukagua kila ripoti.',
  'Copyright: this is my work or I own the rights': 'Haki miliki: hii ni kazi yangu au nina haki zake',
  'Inappropriate content': 'Maudhui yasiyofaa',
  'Misleading title or poster': 'Jina au poster linalopotosha',
  'Something else': 'Jambo jingine',
  'Details': 'Maelezo',
  'Your phone or email (optional)': 'Namba yako ya simu au barua pepe (si lazima)',
  'Send report': 'Tuma ripoti',
  'Describe the work and how you own it.': 'Eleza kazi hiyo na jinsi unavyoimiliki.',
  'Thank you. Your report was received.': 'Asante. Ripoti yako imepokelewa.',

  // Player
  'Video quality': 'Ubora wa video',
  'Auto (adjusts to your network)': 'Auto (hubadilika kulingana na mtandao)',
  'This series is for VIP members only.': 'Series hii ni ya wanachama wa VIP pekee.',
  'Join VIP to watch this series.': 'Jiunge na VIP kutazama series hii.',

  // Payments, receipts, coins
  'Tanzania: mobile money': 'Tanzania: mobile money',
  'Worldwide: cards and wallets': 'Dunia nzima: kadi na wallet',
  '{method} is coming soon.': '{method} inakuja hivi karibuni.',
  'View receipt': 'Tazama risiti',
  'Receipt': 'Risiti',
  'Receipt no.': 'Namba ya risiti',
  'Date': 'Tarehe',
  'Item': 'Bidhaa',
  'You received': 'Ulichopata',
  'Payment method': 'Njia ya malipo',
  'Provider reference': 'Kumbukumbu ya mtoa huduma',
  'Customer': 'Mteja',
  'Contact': 'Mawasiliano',
  'Refunded': 'Imerejeshwa',
  'Refund': 'Marejesho ya pesa',
  'Paid to {seller}': 'Imelipwa kwa {seller}',
  'Questions? Contact {email}': 'Maswali? Wasiliana na {email}',
  'Copied': 'Imenakiliwa',
  'My coins': 'Coins zangu',
  'Coins purchased': 'Coins zilizonunuliwa',
  'Bonus coins': 'Coins za bonasi',
  'Unlocked {title} · EP {n}': 'Umefungua {title} · Ep {n}',
  'Episode unlocked': 'Episode imefunguliwa',
  'Adjustment by AFRIVA': 'Marekebisho ya AFRIVA',
  'No coin activity yet': 'Bado hakuna matumizi ya coins',
  'Balance {n}': 'Salio {n}',

  // Profile / help
  'Transactions and receipts': 'Miamala na risiti',
  'Account and language': 'Akaunti na lugha',
  'Help': 'Msaada',
  'Submit your work': 'Wasilisha Kazi Yako',
  'Need more help? Email support@afriva.com': 'Unahitaji msaada zaidi? Tuma barua pepe kwa support@afriva.com',
  'Which episodes are free?': 'Episode zipi ni za bure?',
  'The first episodes of every series are free (usually episodes 1-8). Each series shows exactly which ones before you start.':
      'Episode za mwanzo za kila series ni bure (kwa kawaida episode 1-8). Kila series inaonyesha wazi ni zipi kabla hujaanza.',
  'How do I unlock the other episodes?': 'Nafunguaje episode nyingine?',
  'Join VIP to watch everything, or unlock single episodes with coins or an episode pack.':
      'Jiunge na VIP kutazama kila kitu, au fungua episode moja moja kwa coins au kifurushi cha episodes.',
  'How do I pay?': 'Nalipaje?',
  'In Tanzania with M-Pesa, Mixx by Yas (Tigo Pesa), Airtel Money or HaloPesa. Outside Tanzania with Visa or Mastercard. You get coins or VIP as soon as the payment is confirmed, plus a receipt.':
      'Tanzania kwa M-Pesa, Mixx by Yas (Tigo Pesa), Airtel Money au HaloPesa. Nje ya Tanzania kwa Visa au Mastercard. Unapata coins au VIP mara malipo yanapothibitishwa, pamoja na risiti.',
  'I paid but did not receive anything': 'Nimelipa lakini sijapata chochote',
  'Open Payment history: if the payment is still pending, wait a moment. If it failed, no money was taken. Otherwise contact us with the payment reference.':
      'Fungua Miamala: kama malipo bado yanasubiri, subiri kidogo. Kama yameshindikana, hakuna pesa iliyokatwa. Vinginevyo wasiliana nasi ukiwa na kumbukumbu ya malipo.',
  'How do I submit my own series?': 'Nawasilishaje series yangu?',
  'Open Profile → Submit your work. AFRIVA reviews every submission before it is published.':
      'Fungua Profile → Wasilisha Kazi Yako. AFRIVA hukagua kila kazi kabla ya kuichapisha.',

  // Creator Studio: review statuses (scope §04)
  'Draft': 'Rasimu',
  'Submitted': 'Imetumwa',
  'In review': 'Inakaguliwa',
  'Changes requested': 'Marekebisho',
  'Approved': 'Imeidhinishwa',
  'Rejected': 'Imekataliwa',
  'Sent for review': 'Imetumwa kwa ukaguzi',
  'Sent again after changes': 'Imetumwa tena baada ya marekebisho',
  'Review started': 'Ukaguzi umeanza',
  'Playback checked': 'Playback imepimwa',
  'Published': 'Imechapishwa',
  'Scheduled for publishing': 'Imepangwa kuchapishwa',
  'Unpublished': 'Imeondolewa hewani',

  // Creator Studio: steps
  'Send your series, episodes, cover, trailer and description.': 'Tuma series, episodes, cover, trailer na maelezo.',
  'AFRIVA checks quality, rights and playback.': 'AFRIVA inakagua ubora, haki za maudhui na playback.',
  'If something needs fixing you get notes and send a new version.': 'Kama kuna marekebisho, unapokea maoni na kutuma toleo jipya.',
  'AFRIVA sets the date, price and free episodes, then publishes.': 'AFRIVA inapanga tarehe, bei na episodes za bure, kisha inachapisha.',

  // Creator Studio: apply
  'Share your African stories with AFRIVA viewers': 'Shiriki hadithi zako za Kiafrika na watazamaji wa AFRIVA',
  'Uploading does not publish your work. Every series is reviewed by AFRIVA first, then published with a date, price and free episodes.':
      'Kupakia hakumaanishi kazi imechapishwa. Kila series inakaguliwa na AFRIVA kwanza, kisha inachapishwa kwa tarehe, bei na episodes za bure.',
  'Studio or creator name': 'Jina la studio au mtayarishaji',
  'Enter a name': 'Weka jina',
  'About you and your work (optional)': 'Kuhusu wewe na kazi zako (si lazima)',
  'Become a creator': 'Kuwa mtayarishaji',
  'Application received. You can start preparing your work.': 'Ombi limepokelewa. Unaweza kuanza kuandaa kazi zako.',
  'You are already a creator': 'Tayari wewe ni mtayarishaji',
  'Open Creator Studio': 'Fungua Creator Studio',
  'Become a creator first': 'Kwanza jisajili kama mtayarishaji',

  // Creator Studio: home
  'Creator Studio': 'Creator Studio',
  'New series': 'Series mpya',
  'My series': 'Series zangu',
  'No series yet': 'Bado huna series',
  'Create your first series, add episodes, then send it for review.': 'Tengeneza series yako ya kwanza, ongeza episodes, kisha uitume kwa ukaguzi.',
  '{n} episodes live': 'Episode {n} ziko hewani',
  'Your creator account is being reviewed': 'Akaunti yako ya mtayarishaji inakaguliwa',
  'Your creator account is suspended': 'Akaunti yako ya mtayarishaji imesimamishwa',
  'You can prepare series and episodes now. You can send them for review once AFRIVA approves your account.':
      'Unaweza kuandaa series na episodes sasa. Utaweza kuzituma kwa ukaguzi baada ya AFRIVA kuidhinisha akaunti yako.',
  'Accept the revenue agreement': 'Kubali mkataba wa mapato',
  'Required before you can send work for review.': 'Inahitajika kabla ya kutuma kazi kwa ukaguzi.',
  'Read agreement': 'Soma mkataba',

  // Creator Studio: agreement
  'Revenue agreement': 'Mkataba wa mapato',
  'Your revenue share: {n}%': 'Mgao wako wa mapato: {n}%',
  'Version {v}': 'Toleo {v}',
  'You accepted this agreement': 'Umekubali mkataba huu',
  'I have read and accept the AFRIVA creator revenue agreement.': 'Nimesoma na nakubali mkataba wa mapato wa watayarishaji wa AFRIVA.',
  'Accept agreement': 'Kubali mkataba',

  // Creator Studio: series form
  'Edit series': 'Badili series',
  'Cover': 'Cover',
  'Cover (vertical 3:4)': 'Cover (wima 3:4)',
  'Choose cover': 'Chagua cover',
  'Change cover': 'Badili cover',
  'Add trailer': 'Ongeza trailer',
  'Replace trailer': 'Badili trailer',
  'Series title': 'Jina la series',
  'Enter a title': 'Weka jina',
  'Description': 'Maelezo',
  'Describe the story': 'Eleza hadithi',
  'Genre': 'Genre',
  'Choose at least one genre.': 'Chagua angalau genre moja.',
  'Age rating': 'Alama ya umri',
  'AFRIVA sets the publishing date, coin price and free episodes after approval.':
      'AFRIVA itapanga tarehe ya kuchapisha, bei ya coins na episodes za bure baada ya kuidhinisha.',
  'Uploading {n}%': 'Inapakia {n}%',
  'Save changes': 'Hifadhi mabadiliko',
  'Create series': 'Tengeneza series',

  // Creator Studio: series detail
  'Delete': 'Futa',
  'Delete episode {n}?': 'Futa episode {n}?',
  'Delete this series and all its episodes?': 'Futa series hii na episodes zake zote?',
  'Send for review': 'Tuma kwa ukaguzi',
  'Send': 'Tuma',
  'AFRIVA will check quality, rights and playback. Your work is not published until it is approved.':
      'AFRIVA itakagua ubora, haki na playback. Kazi yako haitachapishwa hadi iidhinishwe.',
  'I confirm I own or have licensed all rights to this content (video, music, images and trailer).':
      'Nathibitisha kuwa ninamiliki au nina leseni ya haki zote za maudhui haya (video, muziki, picha na trailer).',
  'Sent for review. We will let you know the result here.': 'Imetumwa kwa ukaguzi. Utaona majibu hapa.',
  'Reviewer notes': 'Maoni ya mkaguzi',
  'Under review. You cannot change it until AFRIVA responds.': 'Inakaguliwa. Huwezi kuibadilisha hadi AFRIVA ijibu.',
  'This series was rejected and cannot be sent again.': 'Series hii imekataliwa na haiwezi kutumwa tena.',
  'Add episodes to send for review': 'Ongeza episodes ili kutuma kwa ukaguzi',
  'Send for review ({n} episodes)': 'Tuma kwa ukaguzi (episode {n})',
  'Add episode': 'Ongeza episode',
  'No episodes yet': 'Bado hakuna episodes',
  'Review history': 'Historia ya ukaguzi',
  'Video processing…': 'Video inachakatwa…',
  'Video processing failed': 'Uchakataji wa video umeshindikana',
  'Video ready': 'Video iko tayari',
  'Episode {n}': 'Episode {n}',
  'Episode title (optional)': 'Jina la episode (si lazima)',
  'Choose video': 'Chagua video',
  'Replace video': 'Badili video',
  'Add subtitles (.vtt / .srt, optional)': 'Ongeza subtitles (.vtt / .srt, si lazima)',
  'Choose the episode video.': 'Chagua video ya episode.',
  'Cancel upload': 'Sitisha upakiaji',
  'Save episode': 'Hifadhi episode',
  'After uploading, the video is processed and checked by AFRIVA before viewers can see it.':
      'Baada ya kupakia, video inachakatwa na kukaguliwa na AFRIVA kabla watazamaji hawajaiona.',
};
