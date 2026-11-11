import 'package:material_ui/material_ui.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Strings for code that has no BuildContext (formatters, API errors).
/// Kept in sync with the chosen language by SettingsState.
class L10n {
  L10n._();

  static const supportedCodes = ['en', 'sw'];

  static AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

  static AppLocalizations get current => _current;
  static String get code => _current.localeName;

  static void setCode(String code) {
    _current = lookupAppLocalizations(Locale(supportedCodes.contains(code) ? code : 'en'));
  }
}

extension L10nLabels on AppLocalizations {
  /// Human label for a payment status code from the API.
  String paymentStatus(String status) => switch (status) {
        '' || 'pending' => paymentStatusPending,
        'success' => paymentStatusSuccess,
        'failed' => paymentStatusFailed,
        'cancelled' => paymentStatusCancelled,
        _ => status[0].toUpperCase() + status.substring(1),
      };
}
