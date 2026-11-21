import 'package:url_launcher/url_launcher.dart';

/// Opens a web page outside the app's own screens. Injectable so tests (and
/// the checkout) never depend on a real browser.
typedef UrlOpener = Future<bool> Function(Uri url);

/// Opens [url] in an in-app browser tab (Custom Tabs / SFSafariViewController)
/// and falls back to the system browser. Returns false when nothing opened.
Future<bool> openSecureWebPage(Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {
    // No in-app browser support: try the system browser below.
  }
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
