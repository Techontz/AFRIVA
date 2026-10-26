/// Kiswahili UI strings, keyed by the exact English text. See core/i18n.dart.
///
/// Covers the browsing and watching screens: home, browse, rankings, search,
/// drama detail, For You feed, player, paywall, My List, shell and shared widgets.
const Map<String, String> swWatch = {
  // Bottom navigation / shell
  'Home': 'Nyumbani',
  'For You': 'Kwa Ajili Yako',
  'My List': 'Vipendwa',
  'Profile': 'Profile', // scope §03 navigation label

  // Splash
  'Short dramas. Big African stories.': 'Series fupi. Hadithi kubwa za Kiafrika.',

  // Home
  'Search': 'Tafuta',
  'Help & support': 'Msaada na huduma',
  'Popular': 'Maarufu',
  'New': 'Mpya',
  'Must-sees': 'Usizozikosa',
  'More': 'Zaidi',
  'Nothing to watch yet': 'Bado hakuna cha kutazama',
  'Our studios are busy filming. Pull down to refresh.':
      'Studio zetu zinaendelea kurekodi. Vuta chini ili kuonyesha upya.',

  // Browse / grids
  'Browse': 'Vinjari',
  'Newest': 'Mpya zaidi',
  'No dramas here yet': 'Bado hakuna series hapa',
  'New stories land every week. Check back soon.':
      'Hadithi mpya huingia kila wiki. Rudi tena hivi karibuni.',
  'Tap to load more': 'Gusa ili kupakia zaidi',
  "You've reached the end": 'Umefika mwisho',

  // Rankings
  'Rankings': 'Viwango',
  'Trending': 'Zinazovuma',
  'Most Popular': 'Maarufu zaidi',
  'No rankings yet': 'Bado hakuna viwango',

  // Badges
  'Hot': 'Moto',
  'VIP': 'VIP',

  // Poster cards
  'EP {n}': 'Ep {n}',
  'Coming soon': 'Inakuja hivi karibuni',
  '1 Episode': 'Episode 1',
  '{n} Episodes': 'Episode {n}',
  '{n} episodes': 'Episode {n}',
  '{n} views': 'Watazamaji {n}',

  // Search
  'Search titles, tags, studios': 'Tafuta majina, lebo, studio',
  'Recent searches': 'Utafutaji wa hivi karibuni',
  'Clear': 'Futa',
  'Trending now': 'Zinazovuma sasa',
  'Type to search the Afriva catalog.': 'Andika ili kutafuta katika maktaba ya Afriva.',

  // Drama detail
  'Share': 'Shiriki',
  'by {name}': 'na {name}',
  'Play EP 1': 'Cheza Ep 1',
  'Read more': 'Soma zaidi',
  'Show less': 'Onyesha kidogo',
  'Episodes': 'Episodes',
  'Episodes coming soon': 'Episode zinakuja hivi karibuni',
  'EP 1-{free} free · then {coins} coins/ep or VIP':
      'Ep 1-{free} bure · kisha coins {coins} kwa episode au VIP',
  'You may also like': 'Unaweza pia kupenda',

  // My List / favorites
  'Added to My List': 'Imeongezwa kwenye Vipendwa',
  'Removed from My List': 'Imeondolewa kwenye Vipendwa',
  'In My List': 'Imehifadhiwa',
  'Favorites': 'Vipendwa',
  'History': 'Historia',
  'Your list lives here': 'Orodha yako inakaa hapa',
  'Log in to save dramas and keep track of what you watch across devices.':
      'Ingia ili kuhifadhi series na kufuatilia unachotazama kwenye vifaa vyako vyote.',
  'Log in': 'Ingia',
  'No favorites yet': 'Bado hakuna vipendwa',
  'Tap "My List" on any drama to save it here.':
      'Gusa "Kipendwa" kwenye series yoyote ili kuihifadhi hapa.',
  'Browse dramas': 'Vinjari series',

  // For You feed
  'Your feed is warming up': 'Mlisho wako unaandaliwa',
  'New stories are on the way.': 'Hadithi mpya ziko njiani.',
  'Refresh': 'Onyesha upya',
  "Couldn't load episodes. Try again.": 'Imeshindwa kupakia episode. Jaribu tena.',
  'Tap to retry': 'Gusa ili kujaribu tena',
  'Watch full series · {n} EP': 'Tazama series nzima · Ep {n}',

  // Player
  "That's the finale. Thanks for watching!": 'Hiyo ndiyo episode ya mwisho. Asante kwa kutazama!',
  'EP {n} / {total}': 'Ep {n} / {total}',
  'EP {n} · All {total} episodes': 'Ep {n} · Episode zote {total}',
  'EP 1-{n} free': 'Ep 1-{n} bure',
  'Retry': 'Jaribu tena',
  'Episode {n} is locked': 'Episode {n} imefungwa',
  'Unlock it for {coins} coins or join VIP to watch everything.':
      'Ifungue kwa coins {coins} au jiunge na VIP ili kutazama kila kitu.',
  'Unlock episode': 'Fungua episode',

  // Paywall
  'Unlock Episode {n}': 'Fungua Episode {n}',
  'Keep watching "{title}". The story is just getting good.':
      'Endelea kutazama "{title}". Hadithi ndiyo inanoga.',
  'Log in to unlock': 'Ingia ili kufungua',
  'Unlock with coins': 'Fungua kwa coins',
  'Balance': 'Salio',
  'Unlock for {n} coins': 'Fungua kwa coins {n}',
  'You need {n} coins. Top up {more} more.': 'Unahitaji coins {n}. Ongeza coins {more} zaidi.',
  'Get coins': 'Pata coins',
  'Use episode pack ({n} left)': 'Tumia kifurushi cha episode ({n} zimebaki)',
  'Use 1 episode from my pack': 'Tumia episode 1 kutoka kifurushi changu',
  'Not now': 'Si sasa',
  'Join Afriva VIP': 'Jiunge na Afriva VIP',
  'Every episode unlocked. No waiting.': 'Kila episode imefunguliwa. Hakuna kusubiri.',

  // Shared states and errors (including fixed messages from core/api_client.dart)
  "You're offline": 'Huna mtandao',
  'Something went wrong': 'Hitilafu imetokea',
  'Try again': 'Jaribu tena',
  'Something went wrong. Please try again.': 'Hitilafu imetokea. Tafadhali jaribu tena.',
  'Afriva is taking too long to respond. Please try again.':
      'Afriva inachukua muda mrefu kujibu. Tafadhali jaribu tena.',
  "Can't reach Afriva right now. Check your connection and try again.":
      'Imeshindwa kufikia Afriva kwa sasa. Angalia muunganisho wako kisha ujaribu tena.',
  'Request cancelled': 'Ombi limeghairiwa',
  'Please log in to continue.': 'Tafadhali ingia ili kuendelea.',
  'This episode is locked.': 'Episode hii imefungwa.',
  "You don't have access to this.": 'Huna ruhusa ya kufikia hiki.',
  "We couldn't find that.": 'Hatukuweza kupata hicho.',
  'Please check the highlighted fields.': 'Tafadhali kagua sehemu zilizoangaziwa.',
  'Too many attempts. Please wait a moment.': 'Majaribio mengi mno. Tafadhali subiri kidogo.',
};
