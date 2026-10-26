import 'package:material_ui/material_ui.dart';

import '../l10n/sw_account.dart';
import '../l10n/sw_creator.dart';
import '../l10n/sw_watch.dart';

/// UI translations. The whole interface is Kiswahili (scope §01); English is
/// only an optional fallback in Settings. The English text is the key:
/// `context.tr('My List')` returns the Kiswahili entry while Kiswahili is
/// selected (the default), otherwise the English as written. Placeholders use
/// `{name}`: `context.tr('{n} episodes', {'n': 12})`.
final Map<String, String> _sw = {...swWatch, ...swAccount, ...swCreator};

/// Default and primary UI language.
const String kDefaultLanguage = 'Kiswahili';

class I18n {
  I18n._();

  /// Language for code without a BuildContext (services, state). Kept in sync by
  /// SettingsState; widgets should use `context.tr` so they rebuild on change.
  static String language = kDefaultLanguage;

  static bool get isSwahili => language == 'Kiswahili';

  static String translate(String language, String en, [Map<String, Object?>? args]) {
    var s = language == 'Kiswahili' ? (_sw[en] ?? en) : en;
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    }
    return s;
  }
}

/// Translate with the current language, for code outside the widget tree.
String trNow(String en, [Map<String, Object?>? args]) => I18n.translate(I18n.language, en, args);

/// Provides the selected language to the widget tree; placed in MaterialApp.builder.
class LanguageScope extends InheritedWidget {
  const LanguageScope({super.key, required this.language, required super.child});

  final String language;

  @override
  bool updateShouldNotify(LanguageScope oldWidget) => language != oldWidget.language;
}

extension TrContext on BuildContext {
  /// Translates [en] and registers this widget to rebuild when the language changes.
  String tr(String en, [Map<String, Object?>? args]) {
    final scope = dependOnInheritedWidgetOfExactType<LanguageScope>();
    return I18n.translate(scope?.language ?? I18n.language, en, args);
  }

  bool get isSwahili =>
      (dependOnInheritedWidgetOfExactType<LanguageScope>()?.language ?? I18n.language) == 'Kiswahili';
}
