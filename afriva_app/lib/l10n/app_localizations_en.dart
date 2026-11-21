// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Afriva';

  @override
  String get errorTimeout =>
      'Afriva is taking too long to respond. Please try again.';

  @override
  String get errorNetwork =>
      'Can\'t reach Afriva right now. Check your connection and try again.';

  @override
  String get errorCancelled => 'Request cancelled';

  @override
  String get errorUnauthenticated => 'Please log in to continue.';

  @override
  String get errorEpisodeLocked => 'This episode is locked.';

  @override
  String get errorForbidden => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'We couldn\'t find that.';

  @override
  String get errorValidation => 'Please check the highlighted fields.';

  @override
  String get errorTooManyRequests => 'Too many attempts. Please wait a moment.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mins ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'Yesterday',
    );
    return '$_temp0';
  }

  @override
  String shareWatch(String title) {
    return 'Watch \"$title\" on Afriva';
  }

  @override
  String shareWatchEpisode(String title, int episode) {
    return 'Watch \"$title\", Episode $episode on Afriva';
  }

  @override
  String get planWeeklyVip => 'Weekly VIP';

  @override
  String get planMonthlyVip => 'Monthly VIP';

  @override
  String get planYearlyVip => 'Yearly VIP';

  @override
  String get planEpisodePack => 'Episode pack';

  @override
  String get defaultViewerName => 'Afriva viewer';

  @override
  String get stateOffline => 'You\'re offline';

  @override
  String get stateSomethingWrong => 'Something went wrong';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionMore => 'More';

  @override
  String get badgeNew => 'New';

  @override
  String get badgeHot => 'Hot';

  @override
  String get browseTitle => 'Browse';

  @override
  String get sortPopular => 'Popular';

  @override
  String get sortNewest => 'Newest';

  @override
  String get rankingsTitle => 'Rankings';

  @override
  String get rankTrending => 'Trending';

  @override
  String get rankNew => 'New';

  @override
  String get rankMostPopular => 'Most Popular';

  @override
  String get rankingsEmpty => 'No rankings yet';

  @override
  String get tagline => 'Short dramas. Big African stories.';

  @override
  String get navHome => 'Home';

  @override
  String get navForYou => 'For You';

  @override
  String get navMyList => 'My List';

  @override
  String get navProfile => 'Profile';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle =>
      'Log in to continue your stories, unlock episodes and go VIP.';

  @override
  String get fieldEmailOrPhone => 'Email or phone';

  @override
  String get fieldEmailOrPhoneHint => 'you@example.com or 0712 345 678';

  @override
  String get validateEmailOrPhone => 'Enter your email or phone';

  @override
  String get fieldPassword => 'Password';

  @override
  String get validatePassword => 'Enter your password';

  @override
  String get actionLogIn => 'Log in';

  @override
  String get loginNewTo => 'New to Afriva?';

  @override
  String get actionCreateAccount => 'Create account';

  @override
  String get loginDemoAccounts => 'Demo accounts (debug builds only)';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle =>
      'Free episodes every day. Save your list and pick up where you left off.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get validateName => 'Enter your name';

  @override
  String get fieldPhoneNumber => 'Phone number';

  @override
  String get validatePhoneRequired => 'Enter your phone number';

  @override
  String get validateEmailRequired => 'Enter your email';

  @override
  String get validateEmailInvalid => 'Enter a valid email';

  @override
  String get validatePhoneInvalid => 'Enter a valid phone number';

  @override
  String get passwordHelper => 'At least 8 characters';

  @override
  String get validatePasswordLength => 'Use at least 8 characters';

  @override
  String get registerAgree =>
      'By continuing you agree to the Afriva Terms and Privacy Policy.';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String posterEpisodeCount(int count) {
    return 'EP $count';
  }

  @override
  String get comingSoon => 'Coming soon';

  @override
  String episodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodes',
      one: '1 Episode',
    );
    return '$_temp0';
  }

  @override
  String viewsCount(String views) {
    return '$views views';
  }

  @override
  String get gridEmptyTitle => 'No dramas here yet';

  @override
  String get gridEmptyMessage =>
      'New stories land every week. Check back soon.';

  @override
  String get gridLoadMore => 'Tap to load more';

  @override
  String get gridEnd => 'You\'ve reached the end';

  @override
  String get searchHint => 'Search';

  @override
  String get helpSupport => 'Help & support';

  @override
  String get homeEmptyTitle => 'Nothing to watch yet';

  @override
  String get homeEmptyMessage =>
      'Our studios are busy filming. Pull down to refresh.';

  @override
  String get homeMustSees => 'Must-sees';

  @override
  String get myListFavorites => 'Favorites';

  @override
  String get myListHistory => 'History';

  @override
  String get myListSignedOutTitle => 'Your list lives here';

  @override
  String get myListSignedOutMessage =>
      'Log in to save dramas and keep track of what you watch across devices.';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptyMessage =>
      'Tap \"My List\" on any drama to save it here.';

  @override
  String get browseDramas => 'Browse dramas';

  @override
  String get searchFieldHint => 'Search titles, tags, studios';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get actionClear => 'Clear';

  @override
  String get searchTrendingNow => 'Trending now';

  @override
  String get searchTypeToSearch => 'Type to search the Afriva catalog.';

  @override
  String get addedToMyList => 'Added to My List';

  @override
  String get removedFromMyList => 'Removed from My List';

  @override
  String get inMyList => 'In My List';

  @override
  String get actionShare => 'Share';

  @override
  String byStudio(String studio) {
    return 'by $studio';
  }

  @override
  String playEpisode(int number) {
    return 'Play EP $number';
  }

  @override
  String get showLess => 'Show less';

  @override
  String get readMore => 'Read more';

  @override
  String get episodesTitle => 'Episodes';

  @override
  String get episodesComingSoon => 'Episodes coming soon';

  @override
  String freeEpisodesInfo(int free, int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      free,
      locale: localeName,
      other: 'EP 1-$free free',
      one: 'EP 1 free',
    );
    return '$_temp0 · then $coins coins/ep or VIP';
  }

  @override
  String get youMayAlsoLike => 'You may also like';

  @override
  String get playerFinale => 'That\'s the finale. Thanks for watching!';

  @override
  String playerEpisodeOf(int number, int total) {
    return 'EP $number / $total';
  }

  @override
  String playerAllEpisodes(int number, int total) {
    return 'EP $number · All $total episodes';
  }

  @override
  String freeEpisodesShort(int free) {
    String _temp0 = intl.Intl.pluralLogic(
      free,
      locale: localeName,
      other: 'EP 1-$free free',
      one: 'EP 1 free',
    );
    return '$_temp0';
  }

  @override
  String get actionRetry => 'Retry';

  @override
  String lockedTitle(int number) {
    return 'Episode $number is locked';
  }

  @override
  String lockedMessage(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Unlock it for $coins coins or join VIP to watch everything.',
      one: 'Unlock it for 1 coin or join VIP to watch everything.',
    );
    return '$_temp0';
  }

  @override
  String get unlockEpisode => 'Unlock episode';

  @override
  String paywallTitle(int number) {
    return 'Unlock Episode $number';
  }

  @override
  String paywallSubtitle(String title) {
    return 'Keep watching \"$title\". The story is just getting good.';
  }

  @override
  String get paywallLoginToUnlock => 'Log in to unlock';

  @override
  String get paywallUnlockWithCoins => 'Unlock with coins';

  @override
  String get paywallBalance => 'Balance';

  @override
  String paywallUnlockFor(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Unlock for $coins coins',
      one: 'Unlock for 1 coin',
    );
    return '$_temp0';
  }

  @override
  String paywallNeedCoins(int required, int missing) {
    return 'You need $required coins. Top up $missing more.';
  }

  @override
  String get paywallGetCoins => 'Get coins';

  @override
  String paywallUsePack(int count) {
    return 'Use episode pack ($count left)';
  }

  @override
  String get paywallUseOneFromPack => 'Use 1 episode from my pack';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get paywallJoinVip => 'Join Afriva VIP';

  @override
  String get paywallVipPitch => 'Every episode unlocked. No waiting.';

  @override
  String get feedEmptyTitle => 'Your feed is warming up';

  @override
  String get feedEmptyMessage => 'New stories are on the way.';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get navForYouTitle => 'For You';

  @override
  String get feedEpisodesError => 'Couldn\'t load episodes. Try again.';

  @override
  String get tapToRetry => 'Tap to retry';

  @override
  String feedWatchFullSeries(int count) {
    return 'Watch full series · $count EP';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get watchHistoryTitle => 'Watch history';

  @override
  String get paymentHistoryTitle => 'Payment history';

  @override
  String get vipStoreMenu => 'VIP & coins store';

  @override
  String get actionLogOut => 'Log out';

  @override
  String profileVersion(String version) {
    return 'Afriva · v$version';
  }

  @override
  String get supportBody =>
      'Questions about VIP, coins or payments? Email support@afriva.co.tz and our team will help within 24 hours. Include your payment reference if your question is about a payment.';

  @override
  String get actionGotIt => 'Got it';

  @override
  String get logoutTitle => 'Log out?';

  @override
  String get logoutBody =>
      'Your list, history and VIP stay safe in your account.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String vipUntil(String date) {
    return 'VIP until $date';
  }

  @override
  String get guestTitle => 'Welcome to Afriva';

  @override
  String get guestMessage => 'Log in to sync your list, history and VIP.';

  @override
  String get actionSignUp => 'Sign up';

  @override
  String get coinsTitle => 'Coins';

  @override
  String get actionTopUp => 'Top up';

  @override
  String get membershipTitle => 'Membership';

  @override
  String get membershipPack => 'Pack';

  @override
  String get membershipFree => 'Free';

  @override
  String unlocksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unlocks left',
      one: '1 unlock left',
    );
    return '$_temp0';
  }

  @override
  String get actionManage => 'Manage';

  @override
  String get actionUpgrade => 'Upgrade';

  @override
  String get goVip => 'Go VIP';

  @override
  String goVipPitch(String price) {
    return 'Unlock every episode from $price a week';
  }

  @override
  String get actionJoin => 'Join';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get paymentStatusSuccess => 'Success';

  @override
  String get paymentStatusFailed => 'Failed';

  @override
  String get paymentStatusCancelled => 'Cancelled';

  @override
  String get historyEmptyTitle => 'Nothing watched yet';

  @override
  String get historyEmptyMessage =>
      'Episodes you watch will show up here so you can pick up where you left off.';

  @override
  String get discoverDramas => 'Discover dramas';

  @override
  String get paymentsEmptyTitle => 'No payments yet';

  @override
  String get paymentsEmptyMessage =>
      'Your VIP, episode pack and coin purchases will appear here.';

  @override
  String get paymentDefaultName => 'Afriva purchase';

  @override
  String get referenceCopied => 'Reference copied';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsAutoplay => 'Autoplay next episode';

  @override
  String get settingsAutoplaySubtitle =>
      'Continue to the next episode when one ends';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsClearImageCache => 'Clear image cache';

  @override
  String get settingsClearImageCacheSubtitle => 'Free up space used by posters';

  @override
  String get settingsImageCacheCleared => 'Image cache cleared';

  @override
  String get settingsClearSearchHistory => 'Clear search history';

  @override
  String get settingsSearchHistoryCleared => 'Search history cleared';

  @override
  String get settingsAbout => 'About';

  @override
  String get termsTitle => 'Terms of Service';

  @override
  String get termsBody =>
      'Afriva content is licensed for personal, non-commercial viewing. Subscriptions and coins are non-transferable.';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get privacyBody =>
      'We store only what we need to run your account: your profile, watch history, list and payments. We never sell your data.';

  @override
  String get settingsServer => 'Server';

  @override
  String settingsFooter(String version) {
    return 'Version $version · Made for African storytellers';
  }

  @override
  String get actionClose => 'Close';

  @override
  String get perWeek => '/ week';

  @override
  String get perMonth => '/ month';

  @override
  String get perYear => '/ year';

  @override
  String get paywallJoinVipTitle => 'Afriva VIP';

  @override
  String get vipSubscriptions => 'VIP subscriptions';

  @override
  String get vipSubscriptionsSubtitle => 'Unlimited access to every episode';

  @override
  String get vipEpisodePacks => 'Episode packs';

  @override
  String get vipEpisodePacksSubtitle => 'Unlock any episodes you choose';

  @override
  String get vipCoinsSubtitle => 'Unlock single episodes with coins';

  @override
  String get vipNoPlans => 'No plans available right now';

  @override
  String get vipPaymentsNote =>
      'Payments are processed securely by your chosen provider. VIP renews only when you pay again, with no automatic charges.';

  @override
  String get actionContinue => 'Continue';

  @override
  String get vipYoureVip => 'You\'re VIP';

  @override
  String get vipWatchEverything => 'Watch everything with VIP';

  @override
  String vipActiveUntil(String plan, String date) {
    return '$plan · active until $date';
  }

  @override
  String get vipPerks =>
      'Unlimited episodes · New dramas every week · HD streaming';

  @override
  String vipPackRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pack episodes remaining',
      one: '1 pack episode remaining',
    );
    return '$_temp0';
  }

  @override
  String get vipMostPopular => 'Most popular';

  @override
  String vipPackDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unlock $count episodes of any drama',
      one: 'Unlock 1 episode of any drama',
    );
    return '$_temp0';
  }

  @override
  String vipSubscriptionDescription(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'All episodes unlocked for $days days',
      one: 'All episodes unlocked for 1 day',
    );
    return '$_temp0';
  }

  @override
  String vipPerDay(String price) {
    return '≈ $price/day';
  }

  @override
  String vipBonus(int count) {
    return '+$count bonus';
  }

  @override
  String checkoutStillWaiting(String provider) {
    return 'Still waiting for confirmation from $provider.';
  }

  @override
  String get checkoutTheProvider => 'the provider';

  @override
  String get checkoutTitleSuccess => 'Payment complete';

  @override
  String get checkoutTitlePending => 'Confirm payment';

  @override
  String get checkoutTitleFailed => 'Payment failed';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String checkoutCoins(int coins) {
    return '$coins coins';
  }

  @override
  String checkoutCoinsWithBonus(int coins, int bonus) {
    return '$coins coins + $bonus bonus';
  }

  @override
  String checkoutEpisodeUnlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episode unlocks',
      one: '1 episode unlock',
    );
    return '$_temp0';
  }

  @override
  String checkoutVipDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days of VIP',
      one: '1 day of VIP',
    );
    return '$_temp0';
  }

  @override
  String get checkoutNoMethods => 'No payment methods available';

  @override
  String get checkoutTryLater => 'Please try again later.';

  @override
  String get checkoutMobileMoney => 'Mobile Money';

  @override
  String get checkoutCards => 'Cards';

  @override
  String get checkoutBank => 'Bank';

  @override
  String checkoutPay(String amount) {
    return 'Pay $amount';
  }

  @override
  String get checkoutSecure =>
      'Secure checkout · Afriva never stores card details';

  @override
  String checkoutMethodNumber(String method) {
    return '$method number';
  }

  @override
  String get checkoutInvalidMobile => 'Enter a valid mobile number';

  @override
  String checkoutMobilePrompt(String method) {
    return 'You\'ll receive a prompt on your phone from $method. Enter your PIN to approve.';
  }

  @override
  String checkoutBankInfo(String method) {
    return 'After you continue we\'ll show $method payment instructions and your reference number. Your plan activates as soon as the bank confirms.';
  }

  @override
  String checkoutWaiting(String provider) {
    return 'Waiting for confirmation from $provider.';
  }

  @override
  String get checkoutYourProvider => 'your provider';

  @override
  String get checkoutPending => 'Payment pending';

  @override
  String checkoutUssdHint(String method) {
    return 'Check your phone for the $method prompt and enter your PIN.';
  }

  @override
  String checkoutRedirect(String url) {
    return 'Complete payment at: $url';
  }

  @override
  String get receiptPlan => 'Plan';

  @override
  String get receiptAmount => 'Amount';

  @override
  String get receiptMethod => 'Method';

  @override
  String get receiptReference => 'Reference';

  @override
  String get receiptStatus => 'Status';

  @override
  String get checkoutCheckStatus => 'Check status';

  @override
  String get checkoutIHavePaid => 'I have paid, check now';

  @override
  String get checkoutFinishLater => 'Close, I\'ll finish later';

  @override
  String get checkoutTrackHint =>
      'You can track this payment anytime in Profile › Payment history.';

  @override
  String get successCoinsTitle => 'Coins added!';

  @override
  String get successPackTitle => 'Episode pack ready!';

  @override
  String get successVipTitle => 'Welcome to VIP!';

  @override
  String successCoinsMessage(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins coins are now in your wallet.',
      one: '1 coin is now in your wallet.',
    );
    return '$_temp0';
  }

  @override
  String successPackMessage(int count) {
    return 'Use your $count unlocks on any locked episode.';
  }

  @override
  String get successVipMessage => 'Every episode is unlocked. Enjoy the binge.';

  @override
  String successRef(String reference) {
    return 'Ref $reference';
  }

  @override
  String get successStartWatching => 'Start watching';

  @override
  String get failedCancelledTitle => 'Payment cancelled';

  @override
  String get failedMessage =>
      'No money was taken. You can try again or choose another method.';

  @override
  String get cardDetails => 'Card details';

  @override
  String get cardNumber => 'Card number';

  @override
  String get cardNumberInvalid => 'Enter a valid card number';

  @override
  String get cardExpiry => 'Expiry';

  @override
  String get cardExpiryHint => 'MM/YY';

  @override
  String get cardInvalidMonth => 'Invalid month';

  @override
  String get cardExpired => 'Card expired';

  @override
  String get cardInvalidCvc => 'Invalid CVC';

  @override
  String get cardName => 'Name on card';

  @override
  String get cardNameRequired => 'Enter the name on the card';

  @override
  String get cardHolderPlaceholder => 'CARDHOLDER NAME';

  @override
  String get videoComingSoonTitle => 'Coming soon';

  @override
  String get videoComingSoonMessage =>
      'This episode is still being prepared. Check back shortly.';

  @override
  String get videoComingSoonBadge => 'Coming soon';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'Use device setting';

  @override
  String get playerQuality => 'Quality';

  @override
  String get qualityAuto => 'Auto';

  @override
  String get qualityAutoSubtitle => 'Adjusts to your connection';

  @override
  String get settingsVideoQuality => 'Video quality';

  @override
  String get playerFullScreen => 'Full screen';

  @override
  String get playerExitFullScreen => 'Exit full screen';

  @override
  String get requestToPost => 'Request to post';

  @override
  String get studioStatusPending => 'Pending review';

  @override
  String get studioStatusReady => 'Ready for review';

  @override
  String get studioStatusApproved => 'Approved';

  @override
  String get studioStatusRejected => 'Not approved';

  @override
  String studioSamplesCount(int count, int required) {
    return 'Samples $count/$required';
  }

  @override
  String get studioApplyIntro =>
      'Tell us who you are and where to send your earnings. Afriva reviews every request before you can post.';

  @override
  String get studioSectionDetails => 'Your details';

  @override
  String get studioFullName => 'Full names as on your ID';

  @override
  String get studioSectionIdentity => 'Identity';

  @override
  String get studioIdNida => 'NIDA';

  @override
  String get studioIdPassport => 'Passport';

  @override
  String get studioIdNumberNida => 'NIDA number';

  @override
  String get studioIdNumberPassport => 'Passport number';

  @override
  String get studioIdPhotoNote =>
      'Want to add a photo of your ID? You can upload it on the Afriva Studio website after you apply.';

  @override
  String get studioSectionPayout => 'Payout';

  @override
  String get studioPayoutMobile => 'Mobile money';

  @override
  String get studioPayoutBank => 'Bank';

  @override
  String get studioPayoutProvider => 'Mobile money provider';

  @override
  String get studioBankName => 'Bank name';

  @override
  String get studioAccountName => 'Account name';

  @override
  String get studioAccountNumber => 'Account number';

  @override
  String get studioWalletNumber => 'Wallet phone number';

  @override
  String get studioSectionStudio => 'Studio or channel name';

  @override
  String get studioNameHint => 'Defaults to your name';

  @override
  String get studioOptional => 'Optional';

  @override
  String get studioSectionLogin => 'Login';

  @override
  String get studioLoginHelp =>
      'Choose a password for your new account. If this email already has an Afriva account, enter that account\'s password.';

  @override
  String get studioAcceptPrefix => 'I have read and accept the ';

  @override
  String get studioAcceptLink => 'Afriva creator guidelines';

  @override
  String get studioSubmit => 'Submit request';

  @override
  String get studioValidateRequired => 'This field is required';

  @override
  String get studioValidateIdNumber =>
      'Use 4 to 40 letters, digits, dashes or spaces';

  @override
  String get studioValidatePhone =>
      'Enter 9 to 32 digits (you may use + and spaces)';

  @override
  String get studioValidateProvider => 'Choose a provider';

  @override
  String get studioSuccessTitle => 'Request received';

  @override
  String get studioSuccessBody => 'Thank you. Afriva will review your request.';

  @override
  String get studioSuccessGuest =>
      'You can log in with the email and password you chose to follow your request.';

  @override
  String get studioSuccessExisting =>
      'Log in with your existing Afriva account to follow your request.';

  @override
  String get studioViewStatus => 'View request status';

  @override
  String get studioSamplesTitle => 'Upload 10 sample videos';

  @override
  String get studioSamplesBody =>
      'Before Afriva can approve you, upload 10 sample videos of about 2 minutes each (1 to 3 minutes) on the Afriva Studio website. Large uploads are not available in the app. Open this link in your browser and log in with the same account.';

  @override
  String get studioWebsiteTitle => 'Afriva Studio website';

  @override
  String get studioWebsiteBody =>
      'Open this link in your browser and log in with the same account.';

  @override
  String get studioCopyLink => 'Copy link';

  @override
  String get studioLinkCopied => 'Link copied';

  @override
  String get studioStatusTitle => 'Request status';

  @override
  String studioRejectionReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String studioRevenueSplit(String creator, String platform) {
    return 'Revenue split: you $creator%, Afriva $platform%';
  }

  @override
  String studioSamplesValid(int valid, int required) {
    return '$valid of $required valid samples';
  }

  @override
  String studioSamplesUploaded(int count) {
    return '$count uploaded';
  }

  @override
  String get studioSampleTooShort => 'Too short';

  @override
  String get studioSampleTooLong => 'Too long';

  @override
  String get studioSampleUploading => 'Uploading';

  @override
  String get studioSampleProcessing => 'Processing';

  @override
  String get studioSampleReady => 'Ready';

  @override
  String get studioSampleFailed => 'Failed';

  @override
  String get studioNoSamples => 'No samples uploaded yet';

  @override
  String get studioNoApplicationTitle => 'No request yet';

  @override
  String get studioNoApplicationMessage =>
      'Send a request to start posting on Afriva.';

  @override
  String studioSubmittedOn(String date) {
    return 'Submitted $date';
  }

  @override
  String get studioApprovedBody =>
      'Your account is approved. Log in to Afriva Studio on the website to post.';

  @override
  String get studioReadyBody =>
      'All samples are in. Afriva is reviewing your request.';

  @override
  String get guidelinesTitle => 'Afriva creator guidelines';

  @override
  String get guidelinesIntro =>
      'These rules keep Afriva safe and fair for creators and viewers. By posting on Afriva you agree to them.';

  @override
  String get guidelinesPoint1 =>
      'Only upload content you own or have the rights to publish.';

  @override
  String get guidelinesPoint2 =>
      'No illegal, hateful, sexually exploitative or violent extremist content.';

  @override
  String get guidelinesPoint3 =>
      'Never post content that shows or involves minors in an inappropriate way.';

  @override
  String get guidelinesPoint4 =>
      'Use accurate titles, descriptions and posters. No misleading content.';

  @override
  String get guidelinesPoint5 =>
      'To apply you upload 10 sample videos of about 2 minutes each. Afriva reviews them and approves your account before you can post.';

  @override
  String guidelinesPoint6(String creator, String platform) {
    return 'Revenue split: you receive $creator% of the revenue your content earns (subscription share, coin unlocks, episode packs or any other payment for your content). Afriva keeps $platform%.';
  }

  @override
  String get guidelinesPoint7 =>
      'Payouts go to the payout account you give us, after review.';

  @override
  String get guidelinesPoint8 =>
      'Keep your ID and payout details accurate and up to date.';

  @override
  String get guidelinesPoint9 =>
      'Afriva may remove content and suspend accounts that break these rules.';

  @override
  String get heroPlay => 'Play';

  @override
  String get heroMoreInfo => 'More info';

  @override
  String heroSlide(int n, int total) {
    return '$n of $total';
  }

  @override
  String get actionSeeAll => 'See all';

  @override
  String get episodeFree => 'Free';

  @override
  String get episodeLocked => 'Locked';

  @override
  String get episodeVipUnlocked => 'VIP unlocked';

  @override
  String get rankingsSubtitle => 'Updated daily from real views.';

  @override
  String get rankTabNewHot => 'New & Hot';

  @override
  String get rankTabAllTime => 'All-time Popular';

  @override
  String get rankBlurbTrending => 'What everyone is binging this week';

  @override
  String get rankBlurbNew => 'Fresh series climbing fast';

  @override
  String get rankBlurbPopular => 'The biggest Afriva hits ever';

  @override
  String get payPayWith => 'Pay with';

  @override
  String get payAddNew => 'Add new number or card';

  @override
  String get payAddNewSub => 'Mobile money or Visa / Mastercard';

  @override
  String get payMobileMoney => 'Mobile money';

  @override
  String get payCard => 'Card';

  @override
  String get payComingSoon => 'Coming soon';

  @override
  String get payPhoneLabel => 'Mobile money number';

  @override
  String get payPhoneHelper =>
      'Any network. We send the payment prompt to this phone.';

  @override
  String get payNetworkUnknown => 'We don\'t recognise this network yet';

  @override
  String payNetworkUnavailable(String network) {
    return '$network is not available right now';
  }

  @override
  String get payPhoneInvalid => 'Enter a valid mobile number';

  @override
  String get payCardMonth => 'Month';

  @override
  String get payCardYear => 'Year';

  @override
  String get payCardCvc => 'CVC';

  @override
  String get payCardBrandUnsupported => 'Only Visa and Mastercard are accepted';

  @override
  String get payCardInvalidYear => 'Invalid year';

  @override
  String get payCardInvalidCvc => 'Enter the 3 digits on the back';

  @override
  String get payCardNumberHint => 'Visa or Mastercard';

  @override
  String get paySave => 'Save for faster checkout';

  @override
  String get paySaveSub => 'Next time, pay with one tap';

  @override
  String get payDefault => 'Default';

  @override
  String get payExpired => 'Expired';

  @override
  String payExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get payNeedsDetails => 'Re-enter card details to pay';

  @override
  String payCardEnding(String brand, String last4) {
    return '$brand ending $last4';
  }

  @override
  String get paySecureNote =>
      'Secure checkout. Afriva never asks for your PIN or stores your card number.';

  @override
  String get payTotal => 'Total';

  @override
  String get payDemoNote => 'Test mode: payments are approved automatically.';

  @override
  String get payNothingAvailable =>
      'Payments are not available right now. Please try again later.';

  @override
  String get promptTitle => 'Check your phone';

  @override
  String promptSentTo(String network) {
    return 'We sent a $network prompt to';
  }

  @override
  String get promptSentToPlain => 'We sent a payment prompt to';

  @override
  String get promptPinNote =>
      'Enter your PIN on the prompt that appears on your phone. Afriva will never ask for your PIN.';

  @override
  String get promptWaiting => 'Waiting for your confirmation';

  @override
  String get promptCardTitle => 'Confirming your payment';

  @override
  String get promptCardBody => 'This usually takes a few seconds.';

  @override
  String get promptTimeoutTitle => 'No confirmation yet';

  @override
  String get promptTimeoutBody =>
      'If you approved it on your phone, check again. Otherwise, try once more.';

  @override
  String get promptFailedBody =>
      'No money was taken. Check your balance or number and try again.';

  @override
  String get promptCheckAgain => 'Check again';

  @override
  String get promptSuccess => 'Payment received';

  @override
  String get promptNoPrompt =>
      'No prompt? Make sure your phone is on and unlocked.';

  @override
  String get paymentMethodsTitle => 'Payment methods';

  @override
  String get paymentMethodsEmptyTitle => 'No saved payment methods';

  @override
  String get paymentMethodsEmptyBody =>
      'Save a number or card when you pay and checkout becomes one tap.';

  @override
  String get paymentMethodsAddNumber => 'Add mobile money number';

  @override
  String get paymentMethodsCardNote =>
      'Cards are saved after you pay with them.';

  @override
  String get paymentMethodsMakeDefault => 'Make default';

  @override
  String get paymentMethodsRemove => 'Remove';

  @override
  String get paymentMethodsRemoveTitle => 'Remove this payment method?';

  @override
  String get paymentMethodsRemoveBody => 'You can add it again any time.';

  @override
  String get paymentMethodsRemoved => 'Payment method removed';

  @override
  String get paymentMethodsDefaultSet => 'Default payment method updated';

  @override
  String get paymentMethodsAdded => 'Number saved';

  @override
  String get paymentMethodsSaveNumber => 'Save number';

  @override
  String get settingsPayments => 'Payments';

  @override
  String get payHostedTitle => 'Pay securely by card';

  @override
  String get payHostedBody =>
      'You\'ll enter your card on our payment partner\'s secure page. Afriva never sees your card number.';

  @override
  String get payHostedPhoneLabel => 'Phone number';

  @override
  String get payHostedPhoneHelper => 'For your receipt and payment updates.';

  @override
  String payHostedContinue(String amount) {
    return 'Continue to secure card payment · $amount';
  }

  @override
  String get payHostedOpenFailed =>
      'We couldn\'t open the secure payment page. Tap below to open it again.';

  @override
  String get promptHostedTitle => 'Complete your payment';

  @override
  String get promptHostedBody =>
      'Finish paying on the secure card page. This screen updates by itself once your bank confirms.';

  @override
  String get promptHostedReopen => 'Open the secure page again';

  @override
  String get promptHostedPaid => 'I\'ve paid, check again';

  @override
  String get promptHostedTimeoutBody =>
      'No confirmation yet. If you finished paying, check again. Otherwise, try once more.';

  @override
  String get promptHostedFailedBody =>
      'No money was taken. Check your card details and try again.';

  @override
  String get paymentMethodsCardHostedNote =>
      'Cards are entered on our payment partner\'s secure page each time you pay.';

  @override
  String get authOr => 'or';

  @override
  String get actionContinueWithGoogle => 'Continue with Google';

  @override
  String get googleSignInFailed =>
      'Google sign-in didn\'t finish. Please try again.';

  @override
  String get googleSignInUnavailable =>
      'Google sign-in isn\'t available on this device right now. Use your email or phone instead.';
}
