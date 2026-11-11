// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appName => 'Afriva';

  @override
  String get errorTimeout =>
      'Afriva inachukua muda mrefu kujibu. Tafadhali jaribu tena.';

  @override
  String get errorNetwork =>
      'Imeshindikana kuunganisha na Afriva kwa sasa. Angalia mtandao wako kisha ujaribu tena.';

  @override
  String get errorCancelled => 'Ombi limesitishwa';

  @override
  String get errorUnauthenticated => 'Tafadhali ingia ili kuendelea.';

  @override
  String get errorEpisodeLocked => 'Sehemu hii imefungwa.';

  @override
  String get errorForbidden => 'Huna ruhusa ya kufikia hili.';

  @override
  String get errorNotFound => 'Hatukuweza kupata hicho.';

  @override
  String get errorValidation => 'Tafadhali kagua sehemu zilizowekwa alama.';

  @override
  String get errorTooManyRequests =>
      'Majaribio ni mengi mno. Tafadhali subiri kidogo.';

  @override
  String get errorGeneric => 'Hitilafu imetokea. Tafadhali jaribu tena.';

  @override
  String get timeJustNow => 'Sasa hivi';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dakika $count zilizopita',
      one: 'dakika 1 iliyopita',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'saa $count zilizopita',
      one: 'saa 1 iliyopita',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'siku $count zilizopita',
      one: 'Jana',
    );
    return '$_temp0';
  }

  @override
  String shareWatch(String title) {
    return 'Tazama \"$title\" kwenye Afriva';
  }

  @override
  String shareWatchEpisode(String title, int episode) {
    return 'Tazama \"$title\", Sehemu ya $episode kwenye Afriva';
  }

  @override
  String get planWeeklyVip => 'VIP ya Wiki';

  @override
  String get planMonthlyVip => 'VIP ya Mwezi';

  @override
  String get planYearlyVip => 'VIP ya Mwaka';

  @override
  String get planEpisodePack => 'Kifurushi cha sehemu';

  @override
  String get defaultViewerName => 'Mtazamaji wa Afriva';

  @override
  String get stateOffline => 'Huna mtandao';

  @override
  String get stateSomethingWrong => 'Hitilafu imetokea';

  @override
  String get actionTryAgain => 'Jaribu tena';

  @override
  String get actionMore => 'Zaidi';

  @override
  String get badgeNew => 'Mpya';

  @override
  String get badgeHot => 'Moto';

  @override
  String get browseTitle => 'Vinjari';

  @override
  String get sortPopular => 'Maarufu';

  @override
  String get sortNewest => 'Mpya zaidi';

  @override
  String get rankingsTitle => 'Viwango';

  @override
  String get rankTrending => 'Zinazovuma';

  @override
  String get rankNew => 'Mpya';

  @override
  String get rankMostPopular => 'Maarufu zaidi';

  @override
  String get rankingsEmpty => 'Bado hakuna viwango';

  @override
  String get tagline => 'Tamthilia fupi. Hadithi kubwa za Kiafrika.';

  @override
  String get navHome => 'Nyumbani';

  @override
  String get navForYou => 'Kwako';

  @override
  String get navMyList => 'Orodha Yangu';

  @override
  String get navProfile => 'Wasifu';

  @override
  String get loginTitle => 'Karibu tena';

  @override
  String get loginSubtitle =>
      'Ingia ili kuendelea na hadithi zako, kufungua sehemu na kujiunga na VIP.';

  @override
  String get fieldEmailOrPhone => 'Barua pepe au simu';

  @override
  String get fieldEmailOrPhoneHint => 'wewe@mfano.com au 0712 345 678';

  @override
  String get validateEmailOrPhone => 'Weka barua pepe au namba ya simu';

  @override
  String get fieldPassword => 'Nenosiri';

  @override
  String get validatePassword => 'Weka nenosiri lako';

  @override
  String get actionLogIn => 'Ingia';

  @override
  String get loginNewTo => 'Mgeni kwenye Afriva?';

  @override
  String get actionCreateAccount => 'Fungua akaunti';

  @override
  String get loginDemoAccounts =>
      'Akaunti za majaribio (matoleo ya majaribio pekee)';

  @override
  String get registerTitle => 'Fungua akaunti yako';

  @override
  String get registerSubtitle =>
      'Sehemu za bure kila siku. Hifadhi orodha yako na uendelee ulipoishia.';

  @override
  String get fieldEmail => 'Barua pepe';

  @override
  String get fieldPhone => 'Simu';

  @override
  String get fieldFullName => 'Jina kamili';

  @override
  String get validateName => 'Weka jina lako';

  @override
  String get fieldPhoneNumber => 'Namba ya simu';

  @override
  String get validatePhoneRequired => 'Weka namba yako ya simu';

  @override
  String get validateEmailRequired => 'Weka barua pepe yako';

  @override
  String get validateEmailInvalid => 'Weka barua pepe sahihi';

  @override
  String get validatePhoneInvalid => 'Weka namba ya simu sahihi';

  @override
  String get passwordHelper => 'Angalau herufi 8';

  @override
  String get validatePasswordLength => 'Tumia angalau herufi 8';

  @override
  String get registerAgree =>
      'Kwa kuendelea, unakubali Masharti na Sera ya Faragha ya Afriva.';

  @override
  String get registerHaveAccount => 'Tayari una akaunti?';

  @override
  String posterEpisodeCount(int count) {
    return 'Sehemu $count';
  }

  @override
  String get comingSoon => 'Inakuja hivi karibuni';

  @override
  String episodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sehemu $count',
      one: 'Sehemu 1',
    );
    return '$_temp0';
  }

  @override
  String viewsCount(String views) {
    return 'Mitazamo $views';
  }

  @override
  String get gridEmptyTitle => 'Bado hakuna tamthilia hapa';

  @override
  String get gridEmptyMessage =>
      'Hadithi mpya huingia kila wiki. Rudi tena hivi karibuni.';

  @override
  String get gridLoadMore => 'Gusa ili kupakia zaidi';

  @override
  String get gridEnd => 'Umefika mwisho';

  @override
  String get searchHint => 'Tafuta';

  @override
  String get helpSupport => 'Msaada';

  @override
  String get homeEmptyTitle => 'Bado hakuna cha kutazama';

  @override
  String get homeEmptyMessage =>
      'Studio zetu zinaendelea kurekodi. Vuta chini ili kuonyesha upya.';

  @override
  String get homeMustSees => 'Usikose kutazama';

  @override
  String get myListFavorites => 'Vipendwa';

  @override
  String get myListHistory => 'Historia';

  @override
  String get myListSignedOutTitle => 'Orodha yako iko hapa';

  @override
  String get myListSignedOutMessage =>
      'Ingia ili uhifadhi tamthilia na kufuatilia unachotazama kwenye vifaa vyako vyote.';

  @override
  String get favoritesEmptyTitle => 'Bado huna vipendwa';

  @override
  String get favoritesEmptyMessage =>
      'Gusa \"Orodha Yangu\" kwenye tamthilia yoyote ili kuihifadhi hapa.';

  @override
  String get browseDramas => 'Vinjari tamthilia';

  @override
  String get searchFieldHint => 'Tafuta majina, lebo, studio';

  @override
  String get searchRecent => 'Ulizotafuta hivi karibuni';

  @override
  String get actionClear => 'Futa';

  @override
  String get searchTrendingNow => 'Zinazovuma sasa';

  @override
  String get searchTypeToSearch =>
      'Andika ili kutafuta kwenye maktaba ya Afriva.';

  @override
  String get addedToMyList => 'Imeongezwa kwenye Orodha Yangu';

  @override
  String get removedFromMyList => 'Imeondolewa kwenye Orodha Yangu';

  @override
  String get inMyList => 'Kwenye Orodha';

  @override
  String get actionShare => 'Shiriki';

  @override
  String byStudio(String studio) {
    return 'Imetayarishwa na $studio';
  }

  @override
  String playEpisode(int number) {
    return 'Cheza Sehemu $number';
  }

  @override
  String get showLess => 'Onyesha kidogo';

  @override
  String get readMore => 'Soma zaidi';

  @override
  String get episodesTitle => 'Sehemu';

  @override
  String get episodesComingSoon => 'Sehemu zinakuja hivi karibuni';

  @override
  String freeEpisodesInfo(int free, int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      free,
      locale: localeName,
      other: 'Sehemu 1-$free bure',
      one: 'Sehemu 1 bure',
    );
    return '$_temp0 · kisha sarafu $coins kwa kila sehemu au VIP';
  }

  @override
  String get youMayAlsoLike => 'Huenda pia ukapenda';

  @override
  String get playerFinale => 'Hii ndiyo sehemu ya mwisho. Asante kwa kutazama!';

  @override
  String playerEpisodeOf(int number, int total) {
    return 'Sehemu $number / $total';
  }

  @override
  String playerAllEpisodes(int number, int total) {
    return 'Sehemu $number · Sehemu zote $total';
  }

  @override
  String freeEpisodesShort(int free) {
    String _temp0 = intl.Intl.pluralLogic(
      free,
      locale: localeName,
      other: 'Sehemu 1-$free bure',
      one: 'Sehemu 1 bure',
    );
    return '$_temp0';
  }

  @override
  String get actionRetry => 'Jaribu tena';

  @override
  String lockedTitle(int number) {
    return 'Sehemu ya $number imefungwa';
  }

  @override
  String lockedMessage(int coins) {
    return 'Ifungue kwa sarafu $coins au jiunge na VIP ili kutazama kila kitu.';
  }

  @override
  String get unlockEpisode => 'Fungua sehemu';

  @override
  String paywallTitle(int number) {
    return 'Fungua Sehemu ya $number';
  }

  @override
  String paywallSubtitle(String title) {
    return 'Endelea kutazama \"$title\". Hadithi ndiyo inanoga sasa.';
  }

  @override
  String get paywallLoginToUnlock => 'Ingia ili kufungua';

  @override
  String get paywallUnlockWithCoins => 'Fungua kwa sarafu';

  @override
  String get paywallBalance => 'Salio';

  @override
  String paywallUnlockFor(int coins) {
    return 'Fungua kwa sarafu $coins';
  }

  @override
  String paywallNeedCoins(int required, int missing) {
    return 'Unahitaji sarafu $required. Ongeza sarafu $missing zaidi.';
  }

  @override
  String get paywallGetCoins => 'Pata sarafu';

  @override
  String paywallUsePack(int count) {
    return 'Tumia kifurushi cha sehemu (zimebaki $count)';
  }

  @override
  String get paywallUseOneFromPack => 'Tumia sehemu 1 kutoka kifurushi changu';

  @override
  String get actionNotNow => 'Si sasa';

  @override
  String get paywallJoinVip => 'Jiunge na Afriva VIP';

  @override
  String get paywallVipPitch => 'Sehemu zote zimefunguliwa. Bila kusubiri.';

  @override
  String get feedEmptyTitle => 'Mlisho wako unaandaliwa';

  @override
  String get feedEmptyMessage => 'Hadithi mpya zinakuja.';

  @override
  String get actionRefresh => 'Onyesha upya';

  @override
  String get navForYouTitle => 'Kwa Ajili Yako';

  @override
  String get feedEpisodesError => 'Imeshindikana kupakia sehemu. Jaribu tena.';

  @override
  String get tapToRetry => 'Gusa ili kujaribu tena';

  @override
  String feedWatchFullSeries(int count) {
    return 'Tazama mfululizo mzima · Sehemu $count';
  }

  @override
  String get settingsTitle => 'Mipangilio';

  @override
  String get watchHistoryTitle => 'Historia ya kutazama';

  @override
  String get paymentHistoryTitle => 'Historia ya malipo';

  @override
  String get vipStoreMenu => 'Duka la VIP na sarafu';

  @override
  String get actionLogOut => 'Toka';

  @override
  String profileVersion(String version) {
    return 'Afriva · toleo $version';
  }

  @override
  String get supportBody =>
      'Una maswali kuhusu VIP, sarafu au malipo? Tuma barua pepe kwa support@afriva.co.tz na timu yetu itakusaidia ndani ya saa 24. Weka namba ya kumbukumbu ya malipo kama swali lako linahusu malipo.';

  @override
  String get actionGotIt => 'Sawa';

  @override
  String get logoutTitle => 'Ungependa kutoka?';

  @override
  String get logoutBody =>
      'Orodha yako, historia na VIP vitabaki salama kwenye akaunti yako.';

  @override
  String get actionCancel => 'Ghairi';

  @override
  String vipUntil(String date) {
    return 'VIP hadi $date';
  }

  @override
  String get guestTitle => 'Karibu Afriva';

  @override
  String get guestMessage =>
      'Ingia ili kusawazisha orodha yako, historia na VIP.';

  @override
  String get actionSignUp => 'Jisajili';

  @override
  String get coinsTitle => 'Sarafu';

  @override
  String get actionTopUp => 'Ongeza';

  @override
  String get membershipTitle => 'Uanachama';

  @override
  String get membershipPack => 'Kifurushi';

  @override
  String get membershipFree => 'Bure';

  @override
  String unlocksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zimebaki sehemu $count za kufungua',
      one: 'Imebaki sehemu 1 ya kufungua',
    );
    return '$_temp0';
  }

  @override
  String get actionManage => 'Simamia';

  @override
  String get actionUpgrade => 'Pandisha daraja';

  @override
  String get goVip => 'Jiunge na VIP';

  @override
  String goVipPitch(String price) {
    return 'Fungua kila sehemu kuanzia $price kwa wiki';
  }

  @override
  String get actionJoin => 'Jiunge';

  @override
  String get paymentStatusPending => 'Inasubiri';

  @override
  String get paymentStatusSuccess => 'Imefanikiwa';

  @override
  String get paymentStatusFailed => 'Imeshindikana';

  @override
  String get paymentStatusCancelled => 'Imeghairiwa';

  @override
  String get historyEmptyTitle => 'Bado hujatazama chochote';

  @override
  String get historyEmptyMessage =>
      'Sehemu unazotazama zitaonekana hapa ili uweze kuendelea ulipoishia.';

  @override
  String get discoverDramas => 'Gundua tamthilia';

  @override
  String get paymentsEmptyTitle => 'Bado hakuna malipo';

  @override
  String get paymentsEmptyMessage =>
      'Ununuzi wako wa VIP, vifurushi vya sehemu na sarafu utaonekana hapa.';

  @override
  String get paymentDefaultName => 'Ununuzi wa Afriva';

  @override
  String get referenceCopied => 'Namba ya kumbukumbu imenakiliwa';

  @override
  String get settingsPlayback => 'Uchezaji';

  @override
  String get settingsAutoplay => 'Cheza sehemu inayofuata moja kwa moja';

  @override
  String get settingsAutoplaySubtitle =>
      'Endelea na sehemu inayofuata moja ikiisha';

  @override
  String get settingsLanguage => 'Lugha';

  @override
  String get settingsStorage => 'Hifadhi';

  @override
  String get settingsClearImageCache => 'Futa picha zilizohifadhiwa';

  @override
  String get settingsClearImageCacheSubtitle =>
      'Ongeza nafasi inayotumiwa na picha za tamthilia';

  @override
  String get settingsImageCacheCleared => 'Picha zilizohifadhiwa zimefutwa';

  @override
  String get settingsClearSearchHistory => 'Futa historia ya utafutaji';

  @override
  String get settingsSearchHistoryCleared => 'Historia ya utafutaji imefutwa';

  @override
  String get settingsAbout => 'Kuhusu';

  @override
  String get termsTitle => 'Masharti ya Huduma';

  @override
  String get termsBody =>
      'Maudhui ya Afriva yameruhusiwa kwa matumizi binafsi yasiyo ya kibiashara pekee. Usajili na sarafu haviwezi kuhamishiwa mtu mwingine.';

  @override
  String get privacyTitle => 'Sera ya Faragha';

  @override
  String get privacyBody =>
      'Tunahifadhi tu kile tunachohitaji kuendesha akaunti yako: wasifu wako, historia ya kutazama, orodha na malipo. Hatuuzi kamwe taarifa zako.';

  @override
  String get settingsServer => 'Seva';

  @override
  String settingsFooter(String version) {
    return 'Toleo $version · Imetengenezwa kwa ajili ya wasimulizi wa Kiafrika';
  }

  @override
  String get actionClose => 'Funga';

  @override
  String get perWeek => '/ wiki';

  @override
  String get perMonth => '/ mwezi';

  @override
  String get perYear => '/ mwaka';

  @override
  String get paywallJoinVipTitle => 'Afriva VIP';

  @override
  String get vipSubscriptions => 'Usajili wa VIP';

  @override
  String get vipSubscriptionsSubtitle =>
      'Ufikiaji usio na kikomo wa kila sehemu';

  @override
  String get vipEpisodePacks => 'Vifurushi vya sehemu';

  @override
  String get vipEpisodePacksSubtitle => 'Fungua sehemu zozote utakazochagua';

  @override
  String get vipCoinsSubtitle => 'Fungua sehemu moja moja kwa sarafu';

  @override
  String get vipNoPlans => 'Hakuna vifurushi kwa sasa';

  @override
  String get vipPaymentsNote =>
      'Malipo yanashughulikiwa kwa usalama na mtoa huduma uliyemchagua. VIP huhuishwa pale tu unapolipa tena, bila makato ya moja kwa moja.';

  @override
  String get actionContinue => 'Endelea';

  @override
  String get vipYoureVip => 'Wewe ni VIP';

  @override
  String get vipWatchEverything => 'Tazama kila kitu ukiwa VIP';

  @override
  String vipActiveUntil(String plan, String date) {
    return '$plan · inatumika hadi $date';
  }

  @override
  String get vipPerks =>
      'Sehemu bila kikomo · Tamthilia mpya kila wiki · Picha za HD';

  @override
  String vipPackRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zimebaki sehemu $count kwenye kifurushi',
      one: 'Imebaki sehemu 1 kwenye kifurushi',
    );
    return '$_temp0';
  }

  @override
  String get vipMostPopular => 'Maarufu zaidi';

  @override
  String vipPackDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fungua sehemu $count za tamthilia yoyote',
      one: 'Fungua sehemu 1 ya tamthilia yoyote',
    );
    return '$_temp0';
  }

  @override
  String vipSubscriptionDescription(int days) {
    return 'Sehemu zote zimefunguliwa kwa siku $days';
  }

  @override
  String vipPerDay(String price) {
    return '≈ $price/siku';
  }

  @override
  String vipBonus(int count) {
    return '+$count za ziada';
  }

  @override
  String checkoutStillWaiting(String provider) {
    return 'Bado tunasubiri uthibitisho kutoka $provider.';
  }

  @override
  String get checkoutTheProvider => 'kwa mtoa huduma';

  @override
  String get checkoutTitleSuccess => 'Malipo yamekamilika';

  @override
  String get checkoutTitlePending => 'Thibitisha malipo';

  @override
  String get checkoutTitleFailed => 'Malipo yameshindikana';

  @override
  String get checkoutTitle => 'Malipo';

  @override
  String checkoutCoins(int coins) {
    return 'Sarafu $coins';
  }

  @override
  String checkoutCoinsWithBonus(int coins, int bonus) {
    return 'Sarafu $coins + $bonus za ziada';
  }

  @override
  String checkoutEpisodeUnlocks(int count) {
    return 'Kufungua sehemu $count';
  }

  @override
  String checkoutVipDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Siku $days za VIP',
      one: 'Siku 1 ya VIP',
    );
    return '$_temp0';
  }

  @override
  String get checkoutNoMethods => 'Hakuna njia za malipo kwa sasa';

  @override
  String get checkoutTryLater => 'Tafadhali jaribu tena baadaye.';

  @override
  String get checkoutMobileMoney => 'Pesa kwa Simu';

  @override
  String get checkoutCards => 'Kadi';

  @override
  String get checkoutBank => 'Benki';

  @override
  String checkoutPay(String amount) {
    return 'Lipa $amount';
  }

  @override
  String get checkoutSecure =>
      'Malipo salama · Afriva haihifadhi taarifa za kadi';

  @override
  String checkoutMethodNumber(String method) {
    return 'Namba ya $method';
  }

  @override
  String get checkoutInvalidMobile => 'Weka namba sahihi ya simu';

  @override
  String checkoutMobilePrompt(String method) {
    return 'Utapokea ujumbe wa kuthibitisha kwenye simu yako kutoka $method. Weka PIN yako ili kuidhinisha.';
  }

  @override
  String checkoutBankInfo(String method) {
    return 'Ukiendelea tutakuonyesha maelekezo ya malipo ya $method pamoja na namba yako ya kumbukumbu. Kifurushi chako kitaanza kutumika mara benki itakapothibitisha.';
  }

  @override
  String checkoutWaiting(String provider) {
    return 'Tunasubiri uthibitisho kutoka $provider.';
  }

  @override
  String get checkoutYourProvider => 'kwa mtoa huduma wako';

  @override
  String get checkoutPending => 'Malipo yanasubiri';

  @override
  String checkoutUssdHint(String method) {
    return 'Angalia simu yako kupata ujumbe wa $method kisha weka PIN yako.';
  }

  @override
  String checkoutRedirect(String url) {
    return 'Kamilisha malipo hapa: $url';
  }

  @override
  String get receiptPlan => 'Kifurushi';

  @override
  String get receiptAmount => 'Kiasi';

  @override
  String get receiptMethod => 'Njia';

  @override
  String get receiptReference => 'Kumbukumbu';

  @override
  String get receiptStatus => 'Hali';

  @override
  String get checkoutCheckStatus => 'Angalia hali';

  @override
  String get checkoutIHavePaid => 'Nimelipa, angalia sasa';

  @override
  String get checkoutFinishLater => 'Funga, nitamalizia baadaye';

  @override
  String get checkoutTrackHint =>
      'Unaweza kufuatilia malipo haya wakati wowote kwenye Wasifu › Historia ya malipo.';

  @override
  String get successCoinsTitle => 'Sarafu zimeongezwa!';

  @override
  String get successPackTitle => 'Kifurushi cha sehemu kiko tayari!';

  @override
  String get successVipTitle => 'Karibu VIP!';

  @override
  String successCoinsMessage(int coins) {
    return 'Sarafu $coins sasa ziko kwenye pochi yako.';
  }

  @override
  String successPackMessage(int count) {
    return 'Tumia nafasi zako $count za kufungua kwenye sehemu yoyote iliyofungwa.';
  }

  @override
  String get successVipMessage =>
      'Kila sehemu imefunguliwa. Furahia kutazama bila kikomo.';

  @override
  String successRef(String reference) {
    return 'Kumb. $reference';
  }

  @override
  String get successStartWatching => 'Anza kutazama';

  @override
  String get failedCancelledTitle => 'Malipo yameghairiwa';

  @override
  String get failedMessage =>
      'Hakuna pesa iliyokatwa. Unaweza kujaribu tena au kuchagua njia nyingine.';

  @override
  String get cardDetails => 'Taarifa za kadi';

  @override
  String get cardNumber => 'Namba ya kadi';

  @override
  String get cardNumberInvalid => 'Weka namba sahihi ya kadi';

  @override
  String get cardExpiry => 'Mwisho wa matumizi';

  @override
  String get cardExpiryHint => 'MM/YY';

  @override
  String get cardInvalidMonth => 'Mwezi si sahihi';

  @override
  String get cardExpired => 'Kadi imeisha muda';

  @override
  String get cardInvalidCvc => 'CVC si sahihi';

  @override
  String get cardName => 'Jina lililo kwenye kadi';

  @override
  String get cardNameRequired => 'Weka jina lililo kwenye kadi';

  @override
  String get cardHolderPlaceholder => 'JINA LA MMILIKI';

  @override
  String get videoComingSoonTitle => 'Inakuja hivi karibuni';

  @override
  String get videoComingSoonMessage =>
      'Sehemu hii bado inaandaliwa. Rudi baadaye kidogo.';

  @override
  String get videoComingSoonBadge => 'Inakuja hivi karibuni';

  @override
  String get settingsAppearance => 'Mwonekano';

  @override
  String get themeDark => 'Giza';

  @override
  String get themeLight => 'Mwanga';

  @override
  String get themeSystem => 'Fuata mpangilio wa simu';

  @override
  String get playerQuality => 'Ubora';

  @override
  String get qualityAuto => 'Otomatiki';

  @override
  String get qualityAutoSubtitle => 'Hubadilika kulingana na mtandao wako';

  @override
  String get settingsVideoQuality => 'Ubora wa video';

  @override
  String get playerFullScreen => 'Skrini nzima';

  @override
  String get playerExitFullScreen => 'Toka skrini nzima';

  @override
  String get requestToPost => 'Omba kupost';

  @override
  String get studioStatusPending => 'Inasubiri ukaguzi';

  @override
  String get studioStatusReady => 'Tayari kwa ukaguzi';

  @override
  String get studioStatusApproved => 'Imeidhinishwa';

  @override
  String get studioStatusRejected => 'Haikuidhinishwa';

  @override
  String studioSamplesCount(int count, int required) {
    return 'Video za mfano $count/$required';
  }

  @override
  String get studioApplyIntro =>
      'Tuambie wewe ni nani na mahali pa kutuma mapato yako. Afriva inakagua kila ombi kabla ya kuanza kupost.';

  @override
  String get studioSectionDetails => 'Taarifa zako';

  @override
  String get studioFullName => 'Majina kamili kama yalivyo kwenye kitambulisho';

  @override
  String get studioSectionIdentity => 'Utambulisho';

  @override
  String get studioIdNida => 'NIDA';

  @override
  String get studioIdPassport => 'Pasipoti';

  @override
  String get studioIdNumberNida => 'Namba ya NIDA';

  @override
  String get studioIdNumberPassport => 'Namba ya pasipoti';

  @override
  String get studioIdPhotoNote =>
      'Unataka kuongeza picha ya kitambulisho chako? Unaweza kuipakia kwenye tovuti ya Afriva Studio baada ya kutuma ombi.';

  @override
  String get studioSectionPayout => 'Malipo';

  @override
  String get studioPayoutMobile => 'Pesa kwa simu';

  @override
  String get studioPayoutBank => 'Benki';

  @override
  String get studioPayoutProvider => 'Mtoa huduma wa pesa kwa simu';

  @override
  String get studioBankName => 'Jina la benki';

  @override
  String get studioAccountName => 'Jina la akaunti';

  @override
  String get studioAccountNumber => 'Namba ya akaunti';

  @override
  String get studioWalletNumber => 'Namba ya simu ya pochi';

  @override
  String get studioSectionStudio => 'Jina la studio au chaneli';

  @override
  String get studioNameHint => 'Usipojaza litakuwa jina lako';

  @override
  String get studioOptional => 'Si lazima';

  @override
  String get studioSectionLogin => 'Kuingia';

  @override
  String get studioLoginHelp =>
      'Chagua nenosiri la akaunti yako mpya. Kama barua pepe hii tayari ina akaunti ya Afriva, weka nenosiri la akaunti hiyo.';

  @override
  String get studioAcceptPrefix => 'Nimesoma na ninakubali ';

  @override
  String get studioAcceptLink => 'miongozo ya watayarishi wa Afriva';

  @override
  String get studioSubmit => 'Tuma ombi';

  @override
  String get studioValidateRequired => 'Sehemu hii inahitajika';

  @override
  String get studioValidateIdNumber =>
      'Tumia herufi, namba, vistari au nafasi 4 hadi 40';

  @override
  String get studioValidatePhone =>
      'Weka tarakimu 9 hadi 32 (unaweza kutumia + na nafasi)';

  @override
  String get studioValidateProvider => 'Chagua mtoa huduma';

  @override
  String get studioSuccessTitle => 'Ombi limepokelewa';

  @override
  String get studioSuccessBody => 'Asante. Afriva itakagua ombi lako.';

  @override
  String get studioSuccessGuest =>
      'Unaweza kuingia kwa barua pepe na nenosiri ulilochagua ili kufuatilia ombi lako.';

  @override
  String get studioSuccessExisting =>
      'Ingia kwa akaunti yako ya Afriva iliyopo ili kufuatilia ombi lako.';

  @override
  String get studioViewStatus => 'Angalia hali ya ombi';

  @override
  String get studioSamplesTitle => 'Pakia video 10 za mfano';

  @override
  String get studioSamplesBody =>
      'Kabla Afriva haijakuidhinisha, pakia video 10 za mfano za takriban dakika 2 kila moja (dakika 1 hadi 3) kwenye tovuti ya Afriva Studio. Kupakia faili kubwa hakupatikani kwenye programu. Fungua kiungo hiki kwenye kivinjari na uingie kwa akaunti ile ile.';

  @override
  String get studioWebsiteTitle => 'Tovuti ya Afriva Studio';

  @override
  String get studioWebsiteBody =>
      'Fungua kiungo hiki kwenye kivinjari na uingie kwa akaunti ile ile.';

  @override
  String get studioCopyLink => 'Nakili kiungo';

  @override
  String get studioLinkCopied => 'Kiungo kimenakiliwa';

  @override
  String get studioStatusTitle => 'Hali ya ombi';

  @override
  String studioRejectionReason(String reason) {
    return 'Sababu: $reason';
  }

  @override
  String studioRevenueSplit(String creator, String platform) {
    return 'Mgawanyo wa mapato: wewe $creator%, Afriva $platform%';
  }

  @override
  String studioSamplesValid(int valid, int required) {
    return 'Video $valid kati ya $required ni sahihi';
  }

  @override
  String studioSamplesUploaded(int count) {
    return '$count zimepakiwa';
  }

  @override
  String get studioSampleTooShort => 'Fupi mno';

  @override
  String get studioSampleTooLong => 'Ndefu mno';

  @override
  String get studioSampleUploading => 'Inapakiwa';

  @override
  String get studioSampleProcessing => 'Inachakatwa';

  @override
  String get studioSampleReady => 'Tayari';

  @override
  String get studioSampleFailed => 'Imeshindikana';

  @override
  String get studioNoSamples => 'Bado hakuna video za mfano zilizopakiwa';

  @override
  String get studioNoApplicationTitle => 'Bado hakuna ombi';

  @override
  String get studioNoApplicationMessage =>
      'Tuma ombi ili kuanza kupost kwenye Afriva.';

  @override
  String studioSubmittedOn(String date) {
    return 'Lilitumwa $date';
  }

  @override
  String get studioApprovedBody =>
      'Akaunti yako imeidhinishwa. Ingia kwenye Afriva Studio kwenye tovuti ili kupost.';

  @override
  String get studioReadyBody =>
      'Video zote zimepokelewa. Afriva inakagua ombi lako.';

  @override
  String get guidelinesTitle => 'Miongozo ya watayarishi wa Afriva';

  @override
  String get guidelinesIntro =>
      'Sheria hizi zinaifanya Afriva kuwa salama na ya haki kwa watayarishi na watazamaji. Kwa kupost kwenye Afriva unakubali sheria hizi.';

  @override
  String get guidelinesPoint1 =>
      'Pakia maudhui unayoyamiliki au uliyo na haki ya kuyachapisha tu.';

  @override
  String get guidelinesPoint2 =>
      'Hakuna maudhui yaliyo kinyume cha sheria, ya chuki, ya unyonyaji wa kingono au ya itikadi kali za vurugu.';

  @override
  String get guidelinesPoint3 =>
      'Usipost kamwe maudhui yanayoonyesha au kuhusisha watoto kwa njia isiyofaa.';

  @override
  String get guidelinesPoint4 =>
      'Tumia vichwa, maelezo na picha za jalada sahihi. Hakuna maudhui ya kupotosha.';

  @override
  String get guidelinesPoint5 =>
      'Ili kutuma ombi, pakia video 10 za mfano za takriban dakika 2 kila moja. Afriva itazikagua na kuidhinisha akaunti yako kabla ya kuanza kupost.';

  @override
  String guidelinesPoint6(String creator, String platform) {
    return 'Mgawanyo wa mapato: unapata $creator% ya mapato yanayotokana na maudhui yako (sehemu ya usajili, kufungua kwa sarafu, vifurushi vya sehemu au malipo mengine yoyote ya maudhui yako). Afriva inabaki na $platform%.';
  }

  @override
  String get guidelinesPoint7 =>
      'Malipo yanatumwa kwenye akaunti ya malipo uliyotupa, baada ya ukaguzi.';

  @override
  String get guidelinesPoint8 =>
      'Hakikisha taarifa za kitambulisho na akaunti ya malipo ni sahihi na za sasa.';

  @override
  String get guidelinesPoint9 =>
      'Afriva inaweza kuondoa maudhui na kusimamisha akaunti zinazovunja sheria hizi.';

  @override
  String get heroPlay => 'Tazama';

  @override
  String get heroMoreInfo => 'Maelezo zaidi';

  @override
  String heroSlide(int n, int total) {
    return '$n kati ya $total';
  }

  @override
  String get actionSeeAll => 'Ona zote';

  @override
  String get episodeFree => 'Bure';

  @override
  String get episodeLocked => 'Kimefungwa';

  @override
  String get episodeVipUnlocked => 'Kimefunguliwa kwa VIP';

  @override
  String get rankingsSubtitle =>
      'Husasishwa kila siku kutokana na mitazamo halisi.';

  @override
  String get rankTabNewHot => 'Mpya na Moto';

  @override
  String get rankTabAllTime => 'Maarufu Zaidi';

  @override
  String get rankBlurbTrending => 'Kile ambacho kila mtu anatazama wiki hii';

  @override
  String get rankBlurbNew => 'Mfululizo mpya unaopanda kwa kasi';

  @override
  String get rankBlurbPopular => 'Vibao vikubwa zaidi vya Afriva tangu mwanzo';

  @override
  String get payPayWith => 'Lipa kwa';

  @override
  String get payAddNew => 'Ongeza namba au kadi mpya';

  @override
  String get payAddNewSub => 'Pesa kwa simu au Visa / Mastercard';

  @override
  String get payMobileMoney => 'Pesa kwa simu';

  @override
  String get payCard => 'Kadi';

  @override
  String get payComingSoon => 'Inakuja hivi karibuni';

  @override
  String get payPhoneLabel => 'Namba ya pesa kwa simu';

  @override
  String get payPhoneHelper =>
      'Mtandao wowote. Tunatuma ombi la malipo kwenye simu hii.';

  @override
  String get payNetworkUnknown => 'Bado hatutambui mtandao huu';

  @override
  String payNetworkUnavailable(String network) {
    return '$network haipatikani kwa sasa';
  }

  @override
  String get payPhoneInvalid => 'Weka namba sahihi ya simu';

  @override
  String get payCardMonth => 'Mwezi';

  @override
  String get payCardYear => 'Mwaka';

  @override
  String get payCardCvc => 'CVC';

  @override
  String get payCardBrandUnsupported => 'Tunapokea Visa na Mastercard tu';

  @override
  String get payCardInvalidYear => 'Mwaka si sahihi';

  @override
  String get payCardInvalidCvc => 'Weka tarakimu 3 za nyuma ya kadi';

  @override
  String get payCardNumberHint => 'Visa au Mastercard';

  @override
  String get paySave => 'Hifadhi kwa malipo ya haraka';

  @override
  String get paySaveSub => 'Wakati ujao, lipa kwa mguso mmoja';

  @override
  String get payDefault => 'Chaguo kuu';

  @override
  String get payExpired => 'Muda umeisha';

  @override
  String payExpires(String date) {
    return 'Inaisha $date';
  }

  @override
  String get payNeedsDetails => 'Weka tena taarifa za kadi ili kulipa';

  @override
  String payCardEnding(String brand, String last4) {
    return '$brand inayoishia $last4';
  }

  @override
  String get paySecureNote =>
      'Malipo salama. Afriva haiombi PIN yako wala haihifadhi namba ya kadi yako.';

  @override
  String get payTotal => 'Jumla';

  @override
  String get payDemoNote =>
      'Hali ya majaribio: malipo yanaidhinishwa moja kwa moja.';

  @override
  String get payNothingAvailable =>
      'Malipo hayapatikani kwa sasa. Tafadhali jaribu tena baadaye.';

  @override
  String get promptTitle => 'Angalia simu yako';

  @override
  String promptSentTo(String network) {
    return 'Tumetuma ombi la $network kwenda';
  }

  @override
  String get promptSentToPlain => 'Tumetuma ombi la malipo kwenda';

  @override
  String get promptPinNote =>
      'Weka PIN yako kwenye ombi litakaloonekana kwenye simu yako. Afriva haitakuomba PIN yako kamwe.';

  @override
  String get promptWaiting => 'Tunasubiri uthibitisho wako';

  @override
  String get promptCardTitle => 'Tunathibitisha malipo yako';

  @override
  String get promptCardBody => 'Kwa kawaida huchukua sekunde chache.';

  @override
  String get promptTimeoutTitle => 'Bado hakuna uthibitisho';

  @override
  String get promptTimeoutBody =>
      'Kama uliidhinisha kwenye simu yako, angalia tena. La sivyo, jaribu tena.';

  @override
  String get promptFailedBody =>
      'Hakuna pesa iliyokatwa. Angalia salio au namba yako kisha jaribu tena.';

  @override
  String get promptCheckAgain => 'Angalia tena';

  @override
  String get promptSuccess => 'Malipo yamepokelewa';

  @override
  String get promptNoPrompt =>
      'Hakuna ombi? Hakikisha simu yako imewashwa na haijafungwa.';

  @override
  String get paymentMethodsTitle => 'Njia za malipo';

  @override
  String get paymentMethodsEmptyTitle =>
      'Hakuna njia za malipo zilizohifadhiwa';

  @override
  String get paymentMethodsEmptyBody =>
      'Hifadhi namba au kadi unapolipa na malipo yatakuwa ya mguso mmoja.';

  @override
  String get paymentMethodsAddNumber => 'Ongeza namba ya pesa kwa simu';

  @override
  String get paymentMethodsCardNote => 'Kadi huhifadhiwa baada ya kulipa nazo.';

  @override
  String get paymentMethodsMakeDefault => 'Fanya chaguo kuu';

  @override
  String get paymentMethodsRemove => 'Ondoa';

  @override
  String get paymentMethodsRemoveTitle => 'Ondoa njia hii ya malipo?';

  @override
  String get paymentMethodsRemoveBody =>
      'Unaweza kuiongeza tena wakati wowote.';

  @override
  String get paymentMethodsRemoved => 'Njia ya malipo imeondolewa';

  @override
  String get paymentMethodsDefaultSet => 'Njia kuu ya malipo imesasishwa';

  @override
  String get paymentMethodsAdded => 'Namba imehifadhiwa';

  @override
  String get paymentMethodsSaveNumber => 'Hifadhi namba';

  @override
  String get settingsPayments => 'Malipo';
}
