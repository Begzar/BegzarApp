import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:intl/intl.dart';

/// A promotion the app may show after a connect.
///
/// Plain data plus the two rules that belong to the ad itself: whether it is
/// still inside its run, and which version of it a region reads. Parsing lives
/// in `AdvertisementDto`; picking which ad to show lives in `AdManager`.
class Advertisement {
  const Advertisement({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.clickUrl,
    required this.position,
    required this.priority,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.action,
    required this.buttonColor,
    required this.duration,
    this.byLanguage = const {},
  });

  /// The server's language codes for the two versions the app reads.
  static const persian = 'FA';
  static const english = 'EN';

  final int id;
  final String title;
  final String description;
  final String bannerUrl;
  final String clickUrl;
  final String position;

  /// Higher wins. The rotation pool is drawn from the top of this order.
  final int priority;

  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final String action;
  final String buttonColor;

  /// Seconds the overlay stays closed for before the user may dismiss it.
  final int duration;

  /// This same promotion written for each language the server has it in,
  /// keyed by the server's code. Empty from a server that sends none.
  final Map<String, Advertisement> byLanguage;

  /// The version a device in [region], with the app set to [language], is
  /// shown, or null when it has none.
  ///
  /// An ad with no versions predates them and is shown everywhere, as it
  /// always was. Otherwise Iran reads the Persian version, falling back to the
  /// ad itself. Everyone else reads the version in the app's language, then
  /// English, then nothing: a user abroad is better shown no ad than one they
  /// cannot read.
  Advertisement? forRegion(PurchaseRegion region, {required String language}) {
    if (byLanguage.isEmpty) return this;
    return switch (region) {
      PurchaseRegion.iran => byLanguage[persian] ?? this,
      PurchaseRegion.international =>
        byLanguage[language.toUpperCase()] ?? byLanguage[english],
    };
  }

  /// True when the copy is written in a right-to-left script.
  ///
  /// Read from the text rather than from a language code, because an ad with
  /// no versions carries no code and can still be written in any language.
  bool get readsRightToLeft =>
      Bidi.detectRtlDirectionality('$title $description');

  /// True while the ad is inside its run. Checked on every read rather than
  /// once at parse time, because a stored ad can lapse while the app is open.
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }
}
