import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Afriva'**
  String get appName;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Afriva is taking too long to respond. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Afriva right now. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get errorCancelled;

  /// No description provided for @errorUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please log in to continue.'**
  String get errorUnauthenticated;

  /// No description provided for @errorEpisodeLocked.
  ///
  /// In en, this message translates to:
  /// **'This episode is locked.'**
  String get errorEpisodeLocked;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the highlighted fields.'**
  String get errorValidation;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment.'**
  String get errorTooManyRequests;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} mins ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yesterday} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @shareWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch \"{title}\" on Afriva'**
  String shareWatch(String title);

  /// No description provided for @shareWatchEpisode.
  ///
  /// In en, this message translates to:
  /// **'Watch \"{title}\", Episode {episode} on Afriva'**
  String shareWatchEpisode(String title, int episode);

  /// No description provided for @planWeeklyVip.
  ///
  /// In en, this message translates to:
  /// **'Weekly VIP'**
  String get planWeeklyVip;

  /// No description provided for @planMonthlyVip.
  ///
  /// In en, this message translates to:
  /// **'Monthly VIP'**
  String get planMonthlyVip;

  /// No description provided for @planYearlyVip.
  ///
  /// In en, this message translates to:
  /// **'Yearly VIP'**
  String get planYearlyVip;

  /// No description provided for @planEpisodePack.
  ///
  /// In en, this message translates to:
  /// **'Episode pack'**
  String get planEpisodePack;

  /// No description provided for @defaultViewerName.
  ///
  /// In en, this message translates to:
  /// **'Afriva viewer'**
  String get defaultViewerName;

  /// No description provided for @stateOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get stateOffline;

  /// No description provided for @stateSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateSomethingWrong;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @badgeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get badgeNew;

  /// No description provided for @badgeHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get badgeHot;

  /// No description provided for @browseTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browseTitle;

  /// No description provided for @sortPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get sortPopular;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @rankingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankingsTitle;

  /// No description provided for @rankTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get rankTrending;

  /// No description provided for @rankNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get rankNew;

  /// No description provided for @rankMostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get rankMostPopular;

  /// No description provided for @rankingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rankings yet'**
  String get rankingsEmpty;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Short dramas. Big African stories.'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get navForYou;

  /// No description provided for @navMyList.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get navMyList;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to continue your stories, unlock episodes and go VIP.'**
  String get loginSubtitle;

  /// No description provided for @fieldEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get fieldEmailOrPhone;

  /// No description provided for @fieldEmailOrPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com or 0712 345 678'**
  String get fieldEmailOrPhoneHint;

  /// No description provided for @validateEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone'**
  String get validateEmailOrPhone;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @validatePassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get validatePassword;

  /// No description provided for @actionLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get actionLogIn;

  /// No description provided for @loginNewTo.
  ///
  /// In en, this message translates to:
  /// **'New to Afriva?'**
  String get loginNewTo;

  /// No description provided for @actionCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get actionCreateAccount;

  /// No description provided for @loginDemoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Demo accounts (debug builds only)'**
  String get loginDemoAccounts;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free episodes every day. Save your list and pick up where you left off.'**
  String get registerSubtitle;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @validateName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get validateName;

  /// No description provided for @fieldPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get fieldPhoneNumber;

  /// No description provided for @validatePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get validatePhoneRequired;

  /// No description provided for @validateEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get validateEmailRequired;

  /// No description provided for @validateEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validateEmailInvalid;

  /// No description provided for @validatePhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get validatePhoneInvalid;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelper;

  /// No description provided for @validatePasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get validatePasswordLength;

  /// No description provided for @registerAgree.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the Afriva Terms and Privacy Policy.'**
  String get registerAgree;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get registerHaveAccount;

  /// No description provided for @posterEpisodeCount.
  ///
  /// In en, this message translates to:
  /// **'EP {count}'**
  String posterEpisodeCount(int count);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @episodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Episode} other{{count} Episodes}}'**
  String episodesCount(int count);

  /// No description provided for @viewsCount.
  ///
  /// In en, this message translates to:
  /// **'{views} views'**
  String viewsCount(String views);

  /// No description provided for @gridEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No dramas here yet'**
  String get gridEmptyTitle;

  /// No description provided for @gridEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'New stories land every week. Check back soon.'**
  String get gridEmptyMessage;

  /// No description provided for @gridLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Tap to load more'**
  String get gridLoadMore;

  /// No description provided for @gridEnd.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end'**
  String get gridEnd;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get helpSupport;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to watch yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Our studios are busy filming. Pull down to refresh.'**
  String get homeEmptyMessage;

  /// No description provided for @homeMustSees.
  ///
  /// In en, this message translates to:
  /// **'Must-sees'**
  String get homeMustSees;

  /// No description provided for @myListFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get myListFavorites;

  /// No description provided for @myListHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get myListHistory;

  /// No description provided for @myListSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Your list lives here'**
  String get myListSignedOutTitle;

  /// No description provided for @myListSignedOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Log in to save dramas and keep track of what you watch across devices.'**
  String get myListSignedOutMessage;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap \"My List\" on any drama to save it here.'**
  String get favoritesEmptyMessage;

  /// No description provided for @browseDramas.
  ///
  /// In en, this message translates to:
  /// **'Browse dramas'**
  String get browseDramas;

  /// No description provided for @searchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles, tags, studios'**
  String get searchFieldHint;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @searchTrendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get searchTrendingNow;

  /// No description provided for @searchTypeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search the Afriva catalog.'**
  String get searchTypeToSearch;

  /// No description provided for @addedToMyList.
  ///
  /// In en, this message translates to:
  /// **'Added to My List'**
  String get addedToMyList;

  /// No description provided for @removedFromMyList.
  ///
  /// In en, this message translates to:
  /// **'Removed from My List'**
  String get removedFromMyList;

  /// No description provided for @inMyList.
  ///
  /// In en, this message translates to:
  /// **'In My List'**
  String get inMyList;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @byStudio.
  ///
  /// In en, this message translates to:
  /// **'by {studio}'**
  String byStudio(String studio);

  /// No description provided for @playEpisode.
  ///
  /// In en, this message translates to:
  /// **'Play EP {number}'**
  String playEpisode(int number);

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @episodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodesTitle;

  /// No description provided for @episodesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Episodes coming soon'**
  String get episodesComingSoon;

  /// No description provided for @freeEpisodesInfo.
  ///
  /// In en, this message translates to:
  /// **'{free, plural, =1{EP 1 free} other{EP 1-{free} free}} · then {coins} coins/ep or VIP'**
  String freeEpisodesInfo(int free, int coins);

  /// No description provided for @youMayAlsoLike.
  ///
  /// In en, this message translates to:
  /// **'You may also like'**
  String get youMayAlsoLike;

  /// No description provided for @playerFinale.
  ///
  /// In en, this message translates to:
  /// **'That\'s the finale. Thanks for watching!'**
  String get playerFinale;

  /// No description provided for @playerEpisodeOf.
  ///
  /// In en, this message translates to:
  /// **'EP {number} / {total}'**
  String playerEpisodeOf(int number, int total);

  /// No description provided for @playerAllEpisodes.
  ///
  /// In en, this message translates to:
  /// **'EP {number} · All {total} episodes'**
  String playerAllEpisodes(int number, int total);

  /// No description provided for @freeEpisodesShort.
  ///
  /// In en, this message translates to:
  /// **'{free, plural, =1{EP 1 free} other{EP 1-{free} free}}'**
  String freeEpisodesShort(int free);

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Episode {number} is locked'**
  String lockedTitle(int number);

  /// No description provided for @lockedMessage.
  ///
  /// In en, this message translates to:
  /// **'{coins, plural, =1{Unlock it for 1 coin or join VIP to watch everything.} other{Unlock it for {coins} coins or join VIP to watch everything.}}'**
  String lockedMessage(int coins);

  /// No description provided for @unlockEpisode.
  ///
  /// In en, this message translates to:
  /// **'Unlock episode'**
  String get unlockEpisode;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Episode {number}'**
  String paywallTitle(int number);

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep watching \"{title}\". The story is just getting good.'**
  String paywallSubtitle(String title);

  /// No description provided for @paywallLoginToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Log in to unlock'**
  String get paywallLoginToUnlock;

  /// No description provided for @paywallUnlockWithCoins.
  ///
  /// In en, this message translates to:
  /// **'Unlock with coins'**
  String get paywallUnlockWithCoins;

  /// No description provided for @paywallBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get paywallBalance;

  /// No description provided for @paywallUnlockFor.
  ///
  /// In en, this message translates to:
  /// **'{coins, plural, =1{Unlock for 1 coin} other{Unlock for {coins} coins}}'**
  String paywallUnlockFor(int coins);

  /// No description provided for @paywallNeedCoins.
  ///
  /// In en, this message translates to:
  /// **'You need {required} coins. Top up {missing} more.'**
  String paywallNeedCoins(int required, int missing);

  /// No description provided for @paywallGetCoins.
  ///
  /// In en, this message translates to:
  /// **'Get coins'**
  String get paywallGetCoins;

  /// No description provided for @paywallUsePack.
  ///
  /// In en, this message translates to:
  /// **'Use episode pack ({count} left)'**
  String paywallUsePack(int count);

  /// No description provided for @paywallUseOneFromPack.
  ///
  /// In en, this message translates to:
  /// **'Use 1 episode from my pack'**
  String get paywallUseOneFromPack;

  /// No description provided for @actionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// No description provided for @paywallJoinVip.
  ///
  /// In en, this message translates to:
  /// **'Join Afriva VIP'**
  String get paywallJoinVip;

  /// No description provided for @paywallVipPitch.
  ///
  /// In en, this message translates to:
  /// **'Every episode unlocked. No waiting.'**
  String get paywallVipPitch;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your feed is warming up'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'New stories are on the way.'**
  String get feedEmptyMessage;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @navForYouTitle.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get navForYouTitle;

  /// No description provided for @feedEpisodesError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load episodes. Try again.'**
  String get feedEpisodesError;

  /// No description provided for @tapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// No description provided for @feedWatchFullSeries.
  ///
  /// In en, this message translates to:
  /// **'Watch full series · {count} EP'**
  String feedWatchFullSeries(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @watchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch history'**
  String get watchHistoryTitle;

  /// No description provided for @paymentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistoryTitle;

  /// No description provided for @vipStoreMenu.
  ///
  /// In en, this message translates to:
  /// **'VIP & coins store'**
  String get vipStoreMenu;

  /// No description provided for @actionLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get actionLogOut;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Afriva · v{version}'**
  String profileVersion(String version);

  /// No description provided for @supportBody.
  ///
  /// In en, this message translates to:
  /// **'Questions about VIP, coins or payments? Email support@afriva.co.tz and our team will help within 24 hours. Include your payment reference if your question is about a payment.'**
  String get supportBody;

  /// No description provided for @actionGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get actionGotIt;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutTitle;

  /// No description provided for @logoutBody.
  ///
  /// In en, this message translates to:
  /// **'Your list, history and VIP stay safe in your account.'**
  String get logoutBody;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @vipUntil.
  ///
  /// In en, this message translates to:
  /// **'VIP until {date}'**
  String vipUntil(String date);

  /// No description provided for @guestTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Afriva'**
  String get guestTitle;

  /// No description provided for @guestMessage.
  ///
  /// In en, this message translates to:
  /// **'Log in to sync your list, history and VIP.'**
  String get guestMessage;

  /// No description provided for @actionSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get actionSignUp;

  /// No description provided for @coinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coinsTitle;

  /// No description provided for @actionTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get actionTopUp;

  /// No description provided for @membershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get membershipTitle;

  /// No description provided for @membershipPack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get membershipPack;

  /// No description provided for @membershipFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get membershipFree;

  /// No description provided for @unlocksLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unlock left} other{{count} unlocks left}}'**
  String unlocksLeft(int count);

  /// No description provided for @actionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get actionManage;

  /// No description provided for @actionUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get actionUpgrade;

  /// No description provided for @goVip.
  ///
  /// In en, this message translates to:
  /// **'Go VIP'**
  String get goVip;

  /// No description provided for @goVipPitch.
  ///
  /// In en, this message translates to:
  /// **'Unlock every episode from {price} a week'**
  String goVipPitch(String price);

  /// No description provided for @actionJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get actionJoin;

  /// No description provided for @paymentStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get paymentStatusSuccess;

  /// No description provided for @paymentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get paymentStatusFailed;

  /// No description provided for @paymentStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get paymentStatusCancelled;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing watched yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Episodes you watch will show up here so you can pick up where you left off.'**
  String get historyEmptyMessage;

  /// No description provided for @discoverDramas.
  ///
  /// In en, this message translates to:
  /// **'Discover dramas'**
  String get discoverDramas;

  /// No description provided for @paymentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get paymentsEmptyTitle;

  /// No description provided for @paymentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your VIP, episode pack and coin purchases will appear here.'**
  String get paymentsEmptyMessage;

  /// No description provided for @paymentDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Afriva purchase'**
  String get paymentDefaultName;

  /// No description provided for @referenceCopied.
  ///
  /// In en, this message translates to:
  /// **'Reference copied'**
  String get referenceCopied;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsAutoplay.
  ///
  /// In en, this message translates to:
  /// **'Autoplay next episode'**
  String get settingsAutoplay;

  /// No description provided for @settingsAutoplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue to the next episode when one ends'**
  String get settingsAutoplaySubtitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsClearImageCache.
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get settingsClearImageCache;

  /// No description provided for @settingsClearImageCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free up space used by posters'**
  String get settingsClearImageCacheSubtitle;

  /// No description provided for @settingsImageCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Image cache cleared'**
  String get settingsImageCacheCleared;

  /// No description provided for @settingsClearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get settingsClearSearchHistory;

  /// No description provided for @settingsSearchHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Search history cleared'**
  String get settingsSearchHistoryCleared;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsTitle;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'Afriva content is licensed for personal, non-commercial viewing. Subscriptions and coins are non-transferable.'**
  String get termsBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'We store only what we need to run your account: your profile, watch history, list and payments. We never sell your data.'**
  String get privacyBody;

  /// No description provided for @settingsServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsFooter.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · Made for African storytellers'**
  String settingsFooter(String version);

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @perWeek.
  ///
  /// In en, this message translates to:
  /// **'/ week'**
  String get perWeek;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/ month'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'/ year'**
  String get perYear;

  /// No description provided for @paywallJoinVipTitle.
  ///
  /// In en, this message translates to:
  /// **'Afriva VIP'**
  String get paywallJoinVipTitle;

  /// No description provided for @vipSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'VIP subscriptions'**
  String get vipSubscriptions;

  /// No description provided for @vipSubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited access to every episode'**
  String get vipSubscriptionsSubtitle;

  /// No description provided for @vipEpisodePacks.
  ///
  /// In en, this message translates to:
  /// **'Episode packs'**
  String get vipEpisodePacks;

  /// No description provided for @vipEpisodePacksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock any episodes you choose'**
  String get vipEpisodePacksSubtitle;

  /// No description provided for @vipCoinsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock single episodes with coins'**
  String get vipCoinsSubtitle;

  /// No description provided for @vipNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans available right now'**
  String get vipNoPlans;

  /// No description provided for @vipPaymentsNote.
  ///
  /// In en, this message translates to:
  /// **'Payments are processed securely by your chosen provider. VIP renews only when you pay again, with no automatic charges.'**
  String get vipPaymentsNote;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @vipYoureVip.
  ///
  /// In en, this message translates to:
  /// **'You\'re VIP'**
  String get vipYoureVip;

  /// No description provided for @vipWatchEverything.
  ///
  /// In en, this message translates to:
  /// **'Watch everything with VIP'**
  String get vipWatchEverything;

  /// No description provided for @vipActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'{plan} · active until {date}'**
  String vipActiveUntil(String plan, String date);

  /// No description provided for @vipPerks.
  ///
  /// In en, this message translates to:
  /// **'Unlimited episodes · New dramas every week · HD streaming'**
  String get vipPerks;

  /// No description provided for @vipPackRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack episode remaining} other{{count} pack episodes remaining}}'**
  String vipPackRemaining(int count);

  /// No description provided for @vipMostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most popular'**
  String get vipMostPopular;

  /// No description provided for @vipPackDescription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Unlock 1 episode of any drama} other{Unlock {count} episodes of any drama}}'**
  String vipPackDescription(int count);

  /// No description provided for @vipSubscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{All episodes unlocked for 1 day} other{All episodes unlocked for {days} days}}'**
  String vipSubscriptionDescription(int days);

  /// No description provided for @vipPerDay.
  ///
  /// In en, this message translates to:
  /// **'≈ {price}/day'**
  String vipPerDay(String price);

  /// No description provided for @vipBonus.
  ///
  /// In en, this message translates to:
  /// **'+{count} bonus'**
  String vipBonus(int count);

  /// No description provided for @checkoutStillWaiting.
  ///
  /// In en, this message translates to:
  /// **'Still waiting for confirmation from {provider}.'**
  String checkoutStillWaiting(String provider);

  /// No description provided for @checkoutTheProvider.
  ///
  /// In en, this message translates to:
  /// **'the provider'**
  String get checkoutTheProvider;

  /// No description provided for @checkoutTitleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment complete'**
  String get checkoutTitleSuccess;

  /// No description provided for @checkoutTitlePending.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get checkoutTitlePending;

  /// No description provided for @checkoutTitleFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get checkoutTitleFailed;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutCoins.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String checkoutCoins(int coins);

  /// No description provided for @checkoutCoinsWithBonus.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins + {bonus} bonus'**
  String checkoutCoinsWithBonus(int coins, int bonus);

  /// No description provided for @checkoutEpisodeUnlocks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode unlock} other{{count} episode unlocks}}'**
  String checkoutEpisodeUnlocks(int count);

  /// No description provided for @checkoutVipDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day of VIP} other{{days} days of VIP}}'**
  String checkoutVipDays(int days);

  /// No description provided for @checkoutNoMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods available'**
  String get checkoutNoMethods;

  /// No description provided for @checkoutTryLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later.'**
  String get checkoutTryLater;

  /// No description provided for @checkoutMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get checkoutMobileMoney;

  /// No description provided for @checkoutCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get checkoutCards;

  /// No description provided for @checkoutBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get checkoutBank;

  /// No description provided for @checkoutPay.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String checkoutPay(String amount);

  /// No description provided for @checkoutSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure checkout · Afriva never stores card details'**
  String get checkoutSecure;

  /// No description provided for @checkoutMethodNumber.
  ///
  /// In en, this message translates to:
  /// **'{method} number'**
  String checkoutMethodNumber(String method);

  /// No description provided for @checkoutInvalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number'**
  String get checkoutInvalidMobile;

  /// No description provided for @checkoutMobilePrompt.
  ///
  /// In en, this message translates to:
  /// **'You\'ll receive a prompt on your phone from {method}. Enter your PIN to approve.'**
  String checkoutMobilePrompt(String method);

  /// No description provided for @checkoutBankInfo.
  ///
  /// In en, this message translates to:
  /// **'After you continue we\'ll show {method} payment instructions and your reference number. Your plan activates as soon as the bank confirms.'**
  String checkoutBankInfo(String method);

  /// No description provided for @checkoutWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation from {provider}.'**
  String checkoutWaiting(String provider);

  /// No description provided for @checkoutYourProvider.
  ///
  /// In en, this message translates to:
  /// **'your provider'**
  String get checkoutYourProvider;

  /// No description provided for @checkoutPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get checkoutPending;

  /// No description provided for @checkoutUssdHint.
  ///
  /// In en, this message translates to:
  /// **'Check your phone for the {method} prompt and enter your PIN.'**
  String checkoutUssdHint(String method);

  /// No description provided for @checkoutRedirect.
  ///
  /// In en, this message translates to:
  /// **'Complete payment at: {url}'**
  String checkoutRedirect(String url);

  /// No description provided for @receiptPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get receiptPlan;

  /// No description provided for @receiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get receiptAmount;

  /// No description provided for @receiptMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get receiptMethod;

  /// No description provided for @receiptReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get receiptReference;

  /// No description provided for @receiptStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get receiptStatus;

  /// No description provided for @checkoutCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get checkoutCheckStatus;

  /// No description provided for @checkoutIHavePaid.
  ///
  /// In en, this message translates to:
  /// **'I have paid, check now'**
  String get checkoutIHavePaid;

  /// No description provided for @checkoutFinishLater.
  ///
  /// In en, this message translates to:
  /// **'Close, I\'ll finish later'**
  String get checkoutFinishLater;

  /// No description provided for @checkoutTrackHint.
  ///
  /// In en, this message translates to:
  /// **'You can track this payment anytime in Profile › Payment history.'**
  String get checkoutTrackHint;

  /// No description provided for @successCoinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Coins added!'**
  String get successCoinsTitle;

  /// No description provided for @successPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Episode pack ready!'**
  String get successPackTitle;

  /// No description provided for @successVipTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VIP!'**
  String get successVipTitle;

  /// No description provided for @successCoinsMessage.
  ///
  /// In en, this message translates to:
  /// **'{coins, plural, =1{1 coin is now in your wallet.} other{{coins} coins are now in your wallet.}}'**
  String successCoinsMessage(int coins);

  /// No description provided for @successPackMessage.
  ///
  /// In en, this message translates to:
  /// **'Use your {count} unlocks on any locked episode.'**
  String successPackMessage(int count);

  /// No description provided for @successVipMessage.
  ///
  /// In en, this message translates to:
  /// **'Every episode is unlocked. Enjoy the binge.'**
  String get successVipMessage;

  /// No description provided for @successRef.
  ///
  /// In en, this message translates to:
  /// **'Ref {reference}'**
  String successRef(String reference);

  /// No description provided for @successStartWatching.
  ///
  /// In en, this message translates to:
  /// **'Start watching'**
  String get successStartWatching;

  /// No description provided for @failedCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get failedCancelledTitle;

  /// No description provided for @failedMessage.
  ///
  /// In en, this message translates to:
  /// **'No money was taken. You can try again or choose another method.'**
  String get failedMessage;

  /// No description provided for @cardDetails.
  ///
  /// In en, this message translates to:
  /// **'Card details'**
  String get cardDetails;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get cardNumber;

  /// No description provided for @cardNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid card number'**
  String get cardNumberInvalid;

  /// No description provided for @cardExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get cardExpiry;

  /// No description provided for @cardExpiryHint.
  ///
  /// In en, this message translates to:
  /// **'MM/YY'**
  String get cardExpiryHint;

  /// No description provided for @cardInvalidMonth.
  ///
  /// In en, this message translates to:
  /// **'Invalid month'**
  String get cardInvalidMonth;

  /// No description provided for @cardExpired.
  ///
  /// In en, this message translates to:
  /// **'Card expired'**
  String get cardExpired;

  /// No description provided for @cardInvalidCvc.
  ///
  /// In en, this message translates to:
  /// **'Invalid CVC'**
  String get cardInvalidCvc;

  /// No description provided for @cardName.
  ///
  /// In en, this message translates to:
  /// **'Name on card'**
  String get cardName;

  /// No description provided for @cardNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the name on the card'**
  String get cardNameRequired;

  /// No description provided for @cardHolderPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'CARDHOLDER NAME'**
  String get cardHolderPlaceholder;

  /// No description provided for @videoComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get videoComingSoonTitle;

  /// No description provided for @videoComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'This episode is still being prepared. Check back shortly.'**
  String get videoComingSoonMessage;

  /// No description provided for @videoComingSoonBadge.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get videoComingSoonBadge;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Use device setting'**
  String get themeSystem;

  /// No description provided for @playerQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerQuality;

  /// No description provided for @qualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get qualityAuto;

  /// No description provided for @qualityAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjusts to your connection'**
  String get qualityAutoSubtitle;

  /// No description provided for @settingsVideoQuality.
  ///
  /// In en, this message translates to:
  /// **'Video quality'**
  String get settingsVideoQuality;

  /// No description provided for @playerFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get playerFullScreen;

  /// No description provided for @playerExitFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get playerExitFullScreen;

  /// No description provided for @requestToPost.
  ///
  /// In en, this message translates to:
  /// **'Request to post'**
  String get requestToPost;

  /// No description provided for @studioStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get studioStatusPending;

  /// No description provided for @studioStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for review'**
  String get studioStatusReady;

  /// No description provided for @studioStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get studioStatusApproved;

  /// No description provided for @studioStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get studioStatusRejected;

  /// No description provided for @studioSamplesCount.
  ///
  /// In en, this message translates to:
  /// **'Samples {count}/{required}'**
  String studioSamplesCount(int count, int required);

  /// No description provided for @studioApplyIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us who you are and where to send your earnings. Afriva reviews every request before you can post.'**
  String get studioApplyIntro;

  /// No description provided for @studioSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get studioSectionDetails;

  /// No description provided for @studioFullName.
  ///
  /// In en, this message translates to:
  /// **'Full names as on your ID'**
  String get studioFullName;

  /// No description provided for @studioSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get studioSectionIdentity;

  /// No description provided for @studioIdNida.
  ///
  /// In en, this message translates to:
  /// **'NIDA'**
  String get studioIdNida;

  /// No description provided for @studioIdPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get studioIdPassport;

  /// No description provided for @studioIdNumberNida.
  ///
  /// In en, this message translates to:
  /// **'NIDA number'**
  String get studioIdNumberNida;

  /// No description provided for @studioIdNumberPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport number'**
  String get studioIdNumberPassport;

  /// No description provided for @studioIdPhotoNote.
  ///
  /// In en, this message translates to:
  /// **'Want to add a photo of your ID? You can upload it on the Afriva Studio website after you apply.'**
  String get studioIdPhotoNote;

  /// No description provided for @studioSectionPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get studioSectionPayout;

  /// No description provided for @studioPayoutMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile money'**
  String get studioPayoutMobile;

  /// No description provided for @studioPayoutBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get studioPayoutBank;

  /// No description provided for @studioPayoutProvider.
  ///
  /// In en, this message translates to:
  /// **'Mobile money provider'**
  String get studioPayoutProvider;

  /// No description provided for @studioBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get studioBankName;

  /// No description provided for @studioAccountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get studioAccountName;

  /// No description provided for @studioAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get studioAccountNumber;

  /// No description provided for @studioWalletNumber.
  ///
  /// In en, this message translates to:
  /// **'Wallet phone number'**
  String get studioWalletNumber;

  /// No description provided for @studioSectionStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio or channel name'**
  String get studioSectionStudio;

  /// No description provided for @studioNameHint.
  ///
  /// In en, this message translates to:
  /// **'Defaults to your name'**
  String get studioNameHint;

  /// No description provided for @studioOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get studioOptional;

  /// No description provided for @studioSectionLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get studioSectionLogin;

  /// No description provided for @studioLoginHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a password for your new account. If this email already has an Afriva account, enter that account\'s password.'**
  String get studioLoginHelp;

  /// No description provided for @studioAcceptPrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the '**
  String get studioAcceptPrefix;

  /// No description provided for @studioAcceptLink.
  ///
  /// In en, this message translates to:
  /// **'Afriva creator guidelines'**
  String get studioAcceptLink;

  /// No description provided for @studioSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get studioSubmit;

  /// No description provided for @studioValidateRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get studioValidateRequired;

  /// No description provided for @studioValidateIdNumber.
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 40 letters, digits, dashes or spaces'**
  String get studioValidateIdNumber;

  /// No description provided for @studioValidatePhone.
  ///
  /// In en, this message translates to:
  /// **'Enter 9 to 32 digits (you may use + and spaces)'**
  String get studioValidatePhone;

  /// No description provided for @studioValidateProvider.
  ///
  /// In en, this message translates to:
  /// **'Choose a provider'**
  String get studioValidateProvider;

  /// No description provided for @studioSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Request received'**
  String get studioSuccessTitle;

  /// No description provided for @studioSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Afriva will review your request.'**
  String get studioSuccessBody;

  /// No description provided for @studioSuccessGuest.
  ///
  /// In en, this message translates to:
  /// **'You can log in with the email and password you chose to follow your request.'**
  String get studioSuccessGuest;

  /// No description provided for @studioSuccessExisting.
  ///
  /// In en, this message translates to:
  /// **'Log in with your existing Afriva account to follow your request.'**
  String get studioSuccessExisting;

  /// No description provided for @studioViewStatus.
  ///
  /// In en, this message translates to:
  /// **'View request status'**
  String get studioViewStatus;

  /// No description provided for @studioSamplesTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload 10 sample videos'**
  String get studioSamplesTitle;

  /// No description provided for @studioSamplesBody.
  ///
  /// In en, this message translates to:
  /// **'Before Afriva can approve you, upload 10 sample videos of about 2 minutes each (1 to 3 minutes) on the Afriva Studio website. Large uploads are not available in the app. Open this link in your browser and log in with the same account.'**
  String get studioSamplesBody;

  /// No description provided for @studioWebsiteTitle.
  ///
  /// In en, this message translates to:
  /// **'Afriva Studio website'**
  String get studioWebsiteTitle;

  /// No description provided for @studioWebsiteBody.
  ///
  /// In en, this message translates to:
  /// **'Open this link in your browser and log in with the same account.'**
  String get studioWebsiteBody;

  /// No description provided for @studioCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get studioCopyLink;

  /// No description provided for @studioLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get studioLinkCopied;

  /// No description provided for @studioStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Request status'**
  String get studioStatusTitle;

  /// No description provided for @studioRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String studioRejectionReason(String reason);

  /// No description provided for @studioRevenueSplit.
  ///
  /// In en, this message translates to:
  /// **'Revenue split: you {creator}%, Afriva {platform}%'**
  String studioRevenueSplit(String creator, String platform);

  /// No description provided for @studioSamplesValid.
  ///
  /// In en, this message translates to:
  /// **'{valid} of {required} valid samples'**
  String studioSamplesValid(int valid, int required);

  /// No description provided for @studioSamplesUploaded.
  ///
  /// In en, this message translates to:
  /// **'{count} uploaded'**
  String studioSamplesUploaded(int count);

  /// No description provided for @studioSampleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Too short'**
  String get studioSampleTooShort;

  /// No description provided for @studioSampleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long'**
  String get studioSampleTooLong;

  /// No description provided for @studioSampleUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get studioSampleUploading;

  /// No description provided for @studioSampleProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get studioSampleProcessing;

  /// No description provided for @studioSampleReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get studioSampleReady;

  /// No description provided for @studioSampleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get studioSampleFailed;

  /// No description provided for @studioNoSamples.
  ///
  /// In en, this message translates to:
  /// **'No samples uploaded yet'**
  String get studioNoSamples;

  /// No description provided for @studioNoApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'No request yet'**
  String get studioNoApplicationTitle;

  /// No description provided for @studioNoApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a request to start posting on Afriva.'**
  String get studioNoApplicationMessage;

  /// No description provided for @studioSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted {date}'**
  String studioSubmittedOn(String date);

  /// No description provided for @studioApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is approved. Log in to Afriva Studio on the website to post.'**
  String get studioApprovedBody;

  /// No description provided for @studioReadyBody.
  ///
  /// In en, this message translates to:
  /// **'All samples are in. Afriva is reviewing your request.'**
  String get studioReadyBody;

  /// No description provided for @guidelinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Afriva creator guidelines'**
  String get guidelinesTitle;

  /// No description provided for @guidelinesIntro.
  ///
  /// In en, this message translates to:
  /// **'These rules keep Afriva safe and fair for creators and viewers. By posting on Afriva you agree to them.'**
  String get guidelinesIntro;

  /// No description provided for @guidelinesPoint1.
  ///
  /// In en, this message translates to:
  /// **'Only upload content you own or have the rights to publish.'**
  String get guidelinesPoint1;

  /// No description provided for @guidelinesPoint2.
  ///
  /// In en, this message translates to:
  /// **'No illegal, hateful, sexually exploitative or violent extremist content.'**
  String get guidelinesPoint2;

  /// No description provided for @guidelinesPoint3.
  ///
  /// In en, this message translates to:
  /// **'Never post content that shows or involves minors in an inappropriate way.'**
  String get guidelinesPoint3;

  /// No description provided for @guidelinesPoint4.
  ///
  /// In en, this message translates to:
  /// **'Use accurate titles, descriptions and posters. No misleading content.'**
  String get guidelinesPoint4;

  /// No description provided for @guidelinesPoint5.
  ///
  /// In en, this message translates to:
  /// **'To apply you upload 10 sample videos of about 2 minutes each. Afriva reviews them and approves your account before you can post.'**
  String get guidelinesPoint5;

  /// No description provided for @guidelinesPoint6.
  ///
  /// In en, this message translates to:
  /// **'Revenue split: you receive {creator}% of the revenue your content earns (subscription share, coin unlocks, episode packs or any other payment for your content). Afriva keeps {platform}%.'**
  String guidelinesPoint6(String creator, String platform);

  /// No description provided for @guidelinesPoint7.
  ///
  /// In en, this message translates to:
  /// **'Payouts go to the payout account you give us, after review.'**
  String get guidelinesPoint7;

  /// No description provided for @guidelinesPoint8.
  ///
  /// In en, this message translates to:
  /// **'Keep your ID and payout details accurate and up to date.'**
  String get guidelinesPoint8;

  /// No description provided for @guidelinesPoint9.
  ///
  /// In en, this message translates to:
  /// **'Afriva may remove content and suspend accounts that break these rules.'**
  String get guidelinesPoint9;

  /// Home featured slider: play episode 1
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get heroPlay;

  /// Home featured slider: open drama details
  ///
  /// In en, this message translates to:
  /// **'More info'**
  String get heroMoreInfo;

  /// Featured slider slide position
  ///
  /// In en, this message translates to:
  /// **'{n} of {total}'**
  String heroSlide(int n, int total);

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// No description provided for @episodeFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get episodeFree;

  /// No description provided for @episodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get episodeLocked;

  /// No description provided for @episodeVipUnlocked.
  ///
  /// In en, this message translates to:
  /// **'VIP unlocked'**
  String get episodeVipUnlocked;

  /// No description provided for @rankingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Updated daily from real views.'**
  String get rankingsSubtitle;

  /// No description provided for @rankTabNewHot.
  ///
  /// In en, this message translates to:
  /// **'New & Hot'**
  String get rankTabNewHot;

  /// No description provided for @rankTabAllTime.
  ///
  /// In en, this message translates to:
  /// **'All-time Popular'**
  String get rankTabAllTime;

  /// No description provided for @rankBlurbTrending.
  ///
  /// In en, this message translates to:
  /// **'What everyone is binging this week'**
  String get rankBlurbTrending;

  /// No description provided for @rankBlurbNew.
  ///
  /// In en, this message translates to:
  /// **'Fresh series climbing fast'**
  String get rankBlurbNew;

  /// No description provided for @rankBlurbPopular.
  ///
  /// In en, this message translates to:
  /// **'The biggest Afriva hits ever'**
  String get rankBlurbPopular;

  /// No description provided for @payPayWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get payPayWith;

  /// No description provided for @payAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add new number or card'**
  String get payAddNew;

  /// No description provided for @payAddNewSub.
  ///
  /// In en, this message translates to:
  /// **'Mobile money or Visa / Mastercard'**
  String get payAddNewSub;

  /// No description provided for @payMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile money'**
  String get payMobileMoney;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get payComingSoon;

  /// No description provided for @payPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile money number'**
  String get payPhoneLabel;

  /// No description provided for @payPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Any network. We send the payment prompt to this phone.'**
  String get payPhoneHelper;

  /// No description provided for @payNetworkUnknown.
  ///
  /// In en, this message translates to:
  /// **'We don\'t recognise this network yet'**
  String get payNetworkUnknown;

  /// No description provided for @payNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{network} is not available right now'**
  String payNetworkUnavailable(String network);

  /// No description provided for @payPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number'**
  String get payPhoneInvalid;

  /// No description provided for @payCardMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get payCardMonth;

  /// No description provided for @payCardYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get payCardYear;

  /// No description provided for @payCardCvc.
  ///
  /// In en, this message translates to:
  /// **'CVC'**
  String get payCardCvc;

  /// No description provided for @payCardBrandUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only Visa and Mastercard are accepted'**
  String get payCardBrandUnsupported;

  /// No description provided for @payCardInvalidYear.
  ///
  /// In en, this message translates to:
  /// **'Invalid year'**
  String get payCardInvalidYear;

  /// No description provided for @payCardInvalidCvc.
  ///
  /// In en, this message translates to:
  /// **'Enter the 3 digits on the back'**
  String get payCardInvalidCvc;

  /// No description provided for @payCardNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Visa or Mastercard'**
  String get payCardNumberHint;

  /// No description provided for @paySave.
  ///
  /// In en, this message translates to:
  /// **'Save for faster checkout'**
  String get paySave;

  /// No description provided for @paySaveSub.
  ///
  /// In en, this message translates to:
  /// **'Next time, pay with one tap'**
  String get paySaveSub;

  /// No description provided for @payDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get payDefault;

  /// No description provided for @payExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get payExpired;

  /// No description provided for @payExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String payExpires(String date);

  /// No description provided for @payNeedsDetails.
  ///
  /// In en, this message translates to:
  /// **'Re-enter card details to pay'**
  String get payNeedsDetails;

  /// No description provided for @payCardEnding.
  ///
  /// In en, this message translates to:
  /// **'{brand} ending {last4}'**
  String payCardEnding(String brand, String last4);

  /// No description provided for @paySecureNote.
  ///
  /// In en, this message translates to:
  /// **'Secure checkout. Afriva never asks for your PIN or stores your card number.'**
  String get paySecureNote;

  /// No description provided for @payTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get payTotal;

  /// No description provided for @payDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Test mode: payments are approved automatically.'**
  String get payDemoNote;

  /// No description provided for @payNothingAvailable.
  ///
  /// In en, this message translates to:
  /// **'Payments are not available right now. Please try again later.'**
  String get payNothingAvailable;

  /// No description provided for @promptTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your phone'**
  String get promptTitle;

  /// No description provided for @promptSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a {network} prompt to'**
  String promptSentTo(String network);

  /// No description provided for @promptSentToPlain.
  ///
  /// In en, this message translates to:
  /// **'We sent a payment prompt to'**
  String get promptSentToPlain;

  /// No description provided for @promptPinNote.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN on the prompt that appears on your phone. Afriva will never ask for your PIN.'**
  String get promptPinNote;

  /// No description provided for @promptWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your confirmation'**
  String get promptWaiting;

  /// No description provided for @promptCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment'**
  String get promptCardTitle;

  /// No description provided for @promptCardBody.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few seconds.'**
  String get promptCardBody;

  /// No description provided for @promptTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'No confirmation yet'**
  String get promptTimeoutTitle;

  /// No description provided for @promptTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'If you approved it on your phone, check again. Otherwise, try once more.'**
  String get promptTimeoutBody;

  /// No description provided for @promptFailedBody.
  ///
  /// In en, this message translates to:
  /// **'No money was taken. Check your balance or number and try again.'**
  String get promptFailedBody;

  /// No description provided for @promptCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get promptCheckAgain;

  /// No description provided for @promptSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get promptSuccess;

  /// No description provided for @promptNoPrompt.
  ///
  /// In en, this message translates to:
  /// **'No prompt? Make sure your phone is on and unlocked.'**
  String get promptNoPrompt;

  /// No description provided for @paymentMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethodsTitle;

  /// No description provided for @paymentMethodsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved payment methods'**
  String get paymentMethodsEmptyTitle;

  /// No description provided for @paymentMethodsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save a number or card when you pay and checkout becomes one tap.'**
  String get paymentMethodsEmptyBody;

  /// No description provided for @paymentMethodsAddNumber.
  ///
  /// In en, this message translates to:
  /// **'Add mobile money number'**
  String get paymentMethodsAddNumber;

  /// No description provided for @paymentMethodsCardNote.
  ///
  /// In en, this message translates to:
  /// **'Cards are saved after you pay with them.'**
  String get paymentMethodsCardNote;

  /// No description provided for @paymentMethodsMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get paymentMethodsMakeDefault;

  /// No description provided for @paymentMethodsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get paymentMethodsRemove;

  /// No description provided for @paymentMethodsRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this payment method?'**
  String get paymentMethodsRemoveTitle;

  /// No description provided for @paymentMethodsRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'You can add it again any time.'**
  String get paymentMethodsRemoveBody;

  /// No description provided for @paymentMethodsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Payment method removed'**
  String get paymentMethodsRemoved;

  /// No description provided for @paymentMethodsDefaultSet.
  ///
  /// In en, this message translates to:
  /// **'Default payment method updated'**
  String get paymentMethodsDefaultSet;

  /// No description provided for @paymentMethodsAdded.
  ///
  /// In en, this message translates to:
  /// **'Number saved'**
  String get paymentMethodsAdded;

  /// No description provided for @paymentMethodsSaveNumber.
  ///
  /// In en, this message translates to:
  /// **'Save number'**
  String get paymentMethodsSaveNumber;

  /// No description provided for @settingsPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get settingsPayments;

  /// No description provided for @payHostedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay securely by card'**
  String get payHostedTitle;

  /// No description provided for @payHostedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll enter your card on our payment partner\'s secure page. Afriva never sees your card number.'**
  String get payHostedBody;

  /// No description provided for @payHostedPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get payHostedPhoneLabel;

  /// No description provided for @payHostedPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'For your receipt and payment updates.'**
  String get payHostedPhoneHelper;

  /// No description provided for @payHostedContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to secure card payment · {amount}'**
  String payHostedContinue(String amount);

  /// No description provided for @payHostedOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the secure payment page. Tap below to open it again.'**
  String get payHostedOpenFailed;

  /// No description provided for @promptHostedTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your payment'**
  String get promptHostedTitle;

  /// No description provided for @promptHostedBody.
  ///
  /// In en, this message translates to:
  /// **'Finish paying on the secure card page. This screen updates by itself once your bank confirms.'**
  String get promptHostedBody;

  /// No description provided for @promptHostedReopen.
  ///
  /// In en, this message translates to:
  /// **'Open the secure page again'**
  String get promptHostedReopen;

  /// No description provided for @promptHostedPaid.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid, check again'**
  String get promptHostedPaid;

  /// No description provided for @promptHostedTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'No confirmation yet. If you finished paying, check again. Otherwise, try once more.'**
  String get promptHostedTimeoutBody;

  /// No description provided for @promptHostedFailedBody.
  ///
  /// In en, this message translates to:
  /// **'No money was taken. Check your card details and try again.'**
  String get promptHostedFailedBody;

  /// No description provided for @paymentMethodsCardHostedNote.
  ///
  /// In en, this message translates to:
  /// **'Cards are entered on our payment partner\'s secure page each time you pay.'**
  String get paymentMethodsCardHostedNote;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @actionContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get actionContinueWithGoogle;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in didn\'t finish. Please try again.'**
  String get googleSignInFailed;

  /// No description provided for @googleSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available on this device right now. Use your email or phone instead.'**
  String get googleSignInUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
