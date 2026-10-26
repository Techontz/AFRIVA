/// Kiswahili UI strings, keyed by the exact English text. See core/i18n.dart.
/// Covers account, auth, profile/settings, VIP/checkout and shared core messages.
// Keys already defined in sw_watch.dart are deliberately NOT repeated here: the two maps
// are merged in a const map literal (core/i18n.dart), where a duplicate key is a
// compile-time error. Shared keys provided by sw_watch.dart: 'Log in', 'Profile',
// 'My List', 'Help & support', 'EP {n}', 'Try again' and the ApiClient error messages.
const Map<String, String> swAccount = {
  // Auth: login
  'Welcome back': 'Karibu tena',
  'Log in to continue your stories, unlock episodes and go VIP.':
      'Ingia ili kuendelea na hadithi zako, kufungua episode na kuwa VIP.',
  'Email or phone': 'Barua pepe au simu',
  'you@example.com or 0712 345 678': 'you@example.com au 0712 345 678',
  'Enter your email or phone': 'Weka barua pepe au namba ya simu',
  'Password': 'Nenosiri',
  'Enter your password': 'Weka nenosiri lako',
  'New to Afriva?': 'Bado huna akaunti?',
  'Create account': 'Fungua akaunti',
  'Demo accounts (debug builds only)': 'Akaunti za majaribio (toleo la majaribio tu)',

  // Auth: register
  'Create your account': 'Fungua akaunti yako',
  'Free episodes every day. Save your list and pick up where you left off.':
      'Episode za bure kila siku. Hifadhi vipendwa vyako na uendelee ulipoishia.',
  'Email': 'Barua pepe',
  'Phone': 'Simu',
  'Full name': 'Jina kamili',
  'Enter your name': 'Weka jina lako',
  'Phone number': 'Namba ya simu',
  'Enter your phone number': 'Weka namba yako ya simu',
  'Enter your email': 'Weka barua pepe yako',
  'Enter a valid email': 'Weka barua pepe sahihi',
  'Enter a valid phone number': 'Weka namba ya simu sahihi',
  'At least 8 characters': 'Angalau herufi 8',
  'Use at least 8 characters': 'Tumia angalau herufi 8',
  'By continuing you agree to the Afriva Terms and Privacy Policy.':
      'Kwa kuendelea unakubali Masharti na Sera ya Faragha ya Afriva.',
  'Already have an account?': 'Tayari una akaunti?',

  // Settings
  'Settings': 'Mipangilio',
  'Playback': 'Uchezaji',
  'Autoplay next episode': 'Cheza episode inayofuata moja kwa moja',
  'Continue to the next episode when one ends': 'Endelea na episode inayofuata moja ikiisha',
  'Language': 'Lugha',
  'Storage': 'Nafasi ya hifadhi',
  'Clear image cache': 'Futa akiba ya picha',
  'Free up space used by posters': 'Ongeza nafasi iliyotumiwa na picha za series',
  'Image cache cleared': 'Akiba ya picha imefutwa',
  'Clear search history': 'Futa historia ya utafutaji',
  'Search history cleared': 'Historia ya utafutaji imefutwa',
  'About': 'Kuhusu',
  'Terms of Service': 'Masharti ya Huduma',
  'Afriva content is licensed for personal, non-commercial viewing. Subscriptions and coins are non-transferable.':
      'Maudhui ya Afriva yameruhusiwa kwa utazamaji binafsi usio wa kibiashara. Usajili na coins haviwezi kuhamishiwa kwa mtu mwingine.',
  'Privacy Policy': 'Sera ya Faragha',
  'We store only what we need to run your account: your profile, watch history, list and payments. We never sell your data.':
      'Tunahifadhi tu kile tunachohitaji kuendesha akaunti yako: wasifu wako, historia ya kutazama, orodha na malipo. Hatuuzi data yako kamwe.',
  'Server': 'Seva',
  'Version 1.0.0 · Made for African storytellers': 'Toleo 1.0.0 · Imetengenezwa kwa wasimulizi wa hadithi wa Afrika',
  'Close': 'Funga',

  // Profile
  'Watch history': 'Historia ya kutazama',
  'Payment history': 'Historia ya malipo',
  'VIP & coins store': 'Duka la VIP na coins',
  'Log out': 'Toka',
  'Questions about VIP, coins or payments? Email support@afriva.com and our team will help within 24 hours. Include your payment reference if your question is about a payment.':
      'Una maswali kuhusu VIP, coins au malipo? Tuma barua pepe kwa support@afriva.com na timu yetu itakusaidia ndani ya saa 24. Weka kumbukumbu ya malipo yako kama swali lako linahusu malipo.',
  'Got it': 'Nimeelewa',
  'Log out?': 'Ungependa kutoka?',
  'Your list, history and VIP stay safe in your account.':
      'Orodha yako, historia na VIP vinabaki salama kwenye akaunti yako.',
  'Cancel': 'Ghairi',
  'VIP until {date}': 'VIP hadi {date}',
  'Welcome to Afriva': 'Karibu Afriva',
  'Log in to sync your list, history and VIP.': 'Ingia ili kusawazisha orodha yako, historia na VIP.',
  'Sign up': 'Jisajili',
  'Coins': 'Coins',
  'Top up': 'Ongeza salio',
  'Membership': 'Uanachama',
  'Pack': 'Kifurushi',
  'Free': 'Bure',
  '{n} unlocks left': 'Episode {n} zimebaki',
  'Manage': 'Simamia',
  'Upgrade': 'Pandisha daraja',
  'Go VIP': 'Kuwa VIP',
  'Unlock every episode from 3,000 TZS a week': 'Fungua kila episode kuanzia TZS 3,000 kwa wiki',
  'Join': 'Jiunge',

  // Watch history
  'Nothing watched yet': 'Bado hujatazama chochote',
  'Episodes you watch will show up here so you can pick up where you left off.':
      'Episode unazotazama zitaonekana hapa ili uweze kuendelea ulipoishia.',
  'Discover dramas': 'Gundua series',

  // Payment history / statuses
  'No payments yet': 'Bado hakuna malipo',
  'Your VIP, episode pack and coin purchases will appear here.':
      'Ununuzi wako wa VIP, vifurushi vya episode na coins utaonekana hapa.',
  'Afriva purchase': 'Ununuzi wa Afriva',
  'Reference copied': 'Kumbukumbu imenakiliwa',
  'Pending': 'Inasubiri',
  'Success': 'Imefanikiwa',
  'Failed': 'Imeshindikana',
  'Cancelled': 'Imeghairiwa',

  // VIP store
  'VIP subscriptions': 'Usajili wa VIP',
  'Unlimited access to every episode': 'Ufikiaji usio na kikomo wa kila episode',
  'Episode packs': 'Vifurushi vya episode',
  'Unlock any episodes you choose': 'Fungua episode zozote unazochagua',
  'Unlock single episodes with coins': 'Fungua episode moja moja kwa coins',
  'No plans available right now': 'Hakuna mipango inayopatikana kwa sasa',
  'Payments are processed securely by your chosen provider. VIP renews only when you pay again. No automatic charges.':
      'Malipo yanashughulikiwa kwa usalama na mtoa huduma uliyemchagua. VIP inahuishwa tu unapolipa tena. Hakuna makato ya moja kwa moja.',
  'Continue': 'Endelea',
  "You're VIP": 'Wewe ni VIP',
  'Watch everything with VIP': 'Tazama kila kitu ukiwa na VIP',
  '{plan} · active until {date}': '{plan} · inatumika hadi {date}',
  'Unlimited episodes · New dramas every week · HD streaming':
      'Episode bila kikomo · Series mpya kila wiki · Utiririshaji wa HD',
  '{n} pack episodes remaining': 'Episode {n} za kifurushi zimebaki',
  'Most popular': 'Maarufu zaidi',
  'Unlock {n} episodes of any drama': 'Fungua episode {n} za series yoyote',
  'All episodes unlocked for {n} days': 'Episode zote zimefunguliwa kwa siku {n}',
  '/ week': '/ wiki',
  '/ month': '/ mwezi',
  '/ year': '/ mwaka',
  '≈ {n}/day': '≈ {n}/siku',
  '+{n} bonus': '+{n} za ziada',
  'Weekly VIP': 'VIP ya wiki',
  'Monthly VIP': 'VIP ya mwezi',
  'Yearly VIP': 'VIP ya mwaka',
  'Episode pack': 'Kifurushi cha episode',

  // Checkout
  'Payment complete': 'Malipo yamekamilika',
  'Confirm payment': 'Thibitisha malipo',
  'Payment failed': 'Malipo yameshindikana',
  'Payment cancelled': 'Malipo yameghairiwa',
  'Checkout': 'Malipo',
  '{n} coins': 'Coins {n}',
  '{n} coins + {b} bonus': 'Coins {n} + {b} za bonasi',
  '{n} episode unlocks': 'Episode {n} za kufungua',
  '{n} days of VIP': 'Siku {n} za VIP',
  'No payment methods available': 'Hakuna njia za malipo zinazopatikana',
  'Please try again later.': 'Tafadhali jaribu tena baadaye.',
  'Mobile Money': 'Pesa kwa simu',
  'Cards': 'Kadi',
  'Bank': 'Benki',
  'Pay {amount}': 'Lipa {amount}',
  'Secure checkout · Afriva never stores card details': 'Malipo salama · Afriva haihifadhi taarifa za kadi kamwe',
  '{method} number': 'Namba ya {method}',
  'Enter a valid mobile number': 'Weka namba sahihi ya simu',
  "You'll receive a prompt on your phone from {method}. Enter your PIN to approve.":
      'Utapokea ujumbe kwenye simu yako kutoka {method}. Weka PIN yako ili kuidhinisha.',
  "After you continue we'll show {method} payment instructions and your reference number. Your plan activates as soon as the bank confirms.":
      'Ukiendelea tutakuonyesha maelekezo ya malipo ya {method} na namba yako ya kumbukumbu. Mpango wako utaanza kufanya kazi mara benki itakapothibitisha.',
  'Still waiting for confirmation from {method}.': 'Bado tunasubiri uthibitisho kutoka {method}.',
  'Still waiting for confirmation from the provider.': 'Bado tunasubiri uthibitisho kutoka kwa mtoa huduma.',
  'Waiting for confirmation from {method}.': 'Tunasubiri uthibitisho kutoka {method}.',
  'Waiting for confirmation from your provider.': 'Tunasubiri uthibitisho kutoka kwa mtoa huduma wako.',
  'Payment pending': 'Malipo yanasubiri',
  'Check your phone for the {method} prompt and enter your PIN.':
      'Angalia simu yako kwa ujumbe wa {method} kisha uweke PIN yako.',
  'Complete payment at: {url}': 'Kamilisha malipo kwenye: {url}',
  'Plan': 'Mpango',
  'Amount': 'Kiasi',
  'Method': 'Njia',
  'Reference': 'Kumbukumbu',
  'Status': 'Hali',
  'Check status': 'Angalia hali',
  'I have paid, check now': 'Nimelipa, angalia sasa',
  'Close, I’ll finish later': 'Funga, nitamalizia baadaye',
  'You can track this payment anytime in Profile › Payment history.':
      'Unaweza kufuatilia malipo haya wakati wowote kwenye Wasifu › Historia ya malipo.',
  'Coins added!': 'Coins zimeongezwa!',
  'Episode pack ready!': 'Kifurushi cha episode kiko tayari!',
  'Welcome to VIP!': 'Karibu VIP!',
  '{n} coins are now in your wallet.': 'Coins {n} sasa ziko kwenye pochi yako.',
  'Use your {n} unlocks on any locked episode.':
      'Tumia nafasi zako {n} za kufungua kwenye episode yoyote iliyofungwa.',
  'Every episode is unlocked. Enjoy the binge.': 'Kila episode imefunguliwa. Furahia kutazama bila kikomo.',
  'Ref {ref}': 'Kumb. {ref}',
  'Start watching': 'Anza kutazama',
  'No money was taken. You can try again or choose another method.':
      'Hakuna pesa iliyokatwa. Unaweza kujaribu tena au kuchagua njia nyingine.',

  // Card form
  'Card details': 'Maelezo ya kadi',
  'Card number': 'Namba ya kadi',
  'Enter a valid card number': 'Weka namba sahihi ya kadi',
  'Expiry': 'Tarehe ya mwisho',
  'Invalid month': 'Mwezi si sahihi',
  'Card expired': 'Muda wa kadi umeisha',
  'Invalid CVC': 'CVC si sahihi',
  'Name on card': 'Jina kwenye kadi',
  'Enter the name on the card': 'Weka jina lililo kwenye kadi',
  'CARDHOLDER NAME': 'JINA LA MMILIKI WA KADI',

  // Core: relative times and sharing
  'Just now': 'Sasa hivi',
  '{n}m ago': 'Dakika {n} zilizopita',
  '{n}h ago': 'Saa {n} zilizopita',
  '{n}d ago': 'Siku {n} zilizopita',
  'Watch "{title}" on Afriva': 'Tazama "{title}" kwenye Afriva',
  'Watch "{title}" - Episode {n} on Afriva': 'Tazama "{title}" - Episode {n} kwenye Afriva',
};
