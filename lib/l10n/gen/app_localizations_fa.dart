// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appName => 'بگذر';

  @override
  String get cancel => 'لغو';

  @override
  String get save => 'ذخیره';

  @override
  String get premium => 'پریمیوم';

  @override
  String get basic => 'پایه';

  @override
  String get unknown => '-';

  @override
  String get planPremium => 'پریمیوم';

  @override
  String get planBasic => 'پایه';

  @override
  String get premiumDialogTitle => 'اشتراک پریمیوم';

  @override
  String get premiumDialogMessage =>
      'برای دسترسی به سرورهای پریمیوم وارد شوید یا اشتراک بخرید.';

  @override
  String get buyPremium => 'خرید پریمیوم';

  @override
  String get subscriptionExpiredTitle => 'اشتراک منقضی شده';

  @override
  String get subscriptionExpiredMessage =>
      'اشتراک پریمیوم شما منقضی شده است. برای ادامه استفاده از سرورهای پریمیوم، آن را تمدید کنید.';

  @override
  String get renewSubscription => 'تمدید اشتراک';

  @override
  String get accountInactiveTitle => 'اکانت غیرفعال';

  @override
  String get accountInactiveMessage =>
      'اکانت شما غیرفعال شده است. لطفاً با پشتیبانی تلگرام در ارتباط باشید.';

  @override
  String get otherVpnTurnedOff =>
      'یک VPN دیگر روی دستگاه شما وصل بود و بگذر آن را قطع کرد.';

  @override
  String get otherVpnOnTitle => 'یک VPN دیگر روشن است';

  @override
  String get otherVpnOnMessage =>
      'یک VPN دیگر روی این دستگاه وصل است و بگذر نمی‌تواند آن را خاموش کند. آن را از تنظیمات VPN دستگاه خاموش کنید و دوباره امتحان کنید.';

  @override
  String get otherVpnContinueAnyway => 'در هر صورت ادامه بده';

  @override
  String get openSettings => 'باز کردن تنظیمات';

  @override
  String get contactSupport => 'تماس با پشتیبانی';

  @override
  String get accountInactiveSupportMessage =>
      'سلام، اکانت پریمیوم من غیرفعال شده و نیاز به راهنمایی دارم.';

  @override
  String get premiumSupportMessage =>
      'سلام، می‌خواهم اشتراک پریمیوم بگذر را خریداری کنم.';

  @override
  String get conn_connecting => 'در حال اتصال';

  @override
  String get conn_disconnecting => 'در حال قطع';

  @override
  String get conn_connected => 'محافظت‌شده';

  @override
  String get conn_error => 'اتصال برقرار نشد';

  @override
  String get conn_ready => 'محافظت‌نشده';

  @override
  String get connSub_connecting => 'برای لغو لمس کنید';

  @override
  String get connSub_connectingDesktop => 'برای لغو کلیک کنید';

  @override
  String get connSub_disconnecting => 'در حال بستن تونل';

  @override
  String get connSub_error => 'برای تلاش دوباره لمس کنید';

  @override
  String get connSub_errorDesktop => 'برای تلاش دوباره کلیک کنید';

  @override
  String get connSub_ready => 'برای اتصال خودکار لمس کنید';

  @override
  String get connSub_readyDesktop => 'برای اتصال خودکار کلیک کنید';

  @override
  String get locationUnavailable => 'موقعیت در دسترس نیست';

  @override
  String get tapToTest => 'برای تست لمس کنید';

  @override
  String get tapToTestDesktop => 'برای تست کلیک کنید';

  @override
  String get tapToRetry => 'برای تلاش مجدد لمس کنید';

  @override
  String get tapToRetryDesktop => 'برای تلاش مجدد کلیک کنید';

  @override
  String pingMs(int ms) {
    final intl.NumberFormat msNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String msString = msNumberFormat.format(ms);

    return '$msString میلی‌ثانیه';
  }

  @override
  String get pingExcellent => 'عالی';

  @override
  String get pingGood => 'خوب';

  @override
  String get pingFair => 'متوسط';

  @override
  String get pingPoor => 'ضعیف';

  @override
  String get settingsCategoryApp => 'برنامه';

  @override
  String get settingsCategoryGeneral => 'عمومی';

  @override
  String get settingsCategoryConnection => 'اتصال';

  @override
  String get settingsCategoryNetwork => 'شبکه';

  @override
  String get settingsCategoryExperimental => 'آزمایشی';

  @override
  String get experimentalTitle => 'تنظیمات آزمایشی';

  @override
  String get experimentalEnabled =>
      'اتصال رایگان از Cloudflare WARP استفاده می‌کند';

  @override
  String get experimentalDisabled =>
      'اتصال رایگان از سرورهای بگذر استفاده می‌کند';

  @override
  String get warpModeTitle => 'حالت WARP';

  @override
  String get warpModeMasque => 'MASQUE';

  @override
  String get warpModeWarp => 'WireGuard';

  @override
  String get warpModeGool => 'WARP درون WARP';

  @override
  String get warpModeMasquePsiphon => 'سایفون روی MASQUE';

  @override
  String get warpModePsiphon => 'سایفون روی WARP';

  @override
  String get languageTitle => 'زبان';

  @override
  String get languageSubtitle => 'تغییر زبان برنامه';

  @override
  String get themeTitle => 'پوسته';

  @override
  String get themeSystem => 'پیش‌فرض سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String get appRoutingTitle => 'مسیریابی اپ‌ها';

  @override
  String get appRoutingSubtitleNone =>
      'انتخاب کنید کدام اپ‌ها از VPN استفاده کنند';

  @override
  String appRoutingSubtitleAllExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'همه به‌جز  $countString اپ',
      one: 'همه به‌جز  $countString اپ',
    );
    return '$_temp0';
  }

  @override
  String appRoutingSubtitleOnly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فقط $countString اپ',
      one: 'فقط $countString اپ',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingNeedsVpn =>
      'برای مسیریابی اپ‌ها حالت فقط پروکسی را خاموش کنید';

  @override
  String get appRoutingModeAllExcept =>
      'همه اپ‌ها از VPN استفاده می‌کنند، به‌جز…';

  @override
  String get appRoutingModeAllExceptHint =>
      'همه‌چیز از VPN عبور می‌کند. اپ‌هایی که انتخاب کنید مستقیم وصل می‌شوند.';

  @override
  String get appRoutingModeOnly => 'فقط برخی اپ‌ها از VPN استفاده می‌کنند';

  @override
  String get appRoutingModeOnlyHint =>
      'هیچ‌چیز جز اپ‌هایی که انتخاب کنید از VPN عبور نمی‌کند. اگر اپی انتخاب نشود، همه اپ‌ها از VPN عبور می‌کنند.';

  @override
  String get appRoutingPickAllExcept =>
      'اپ‌هایی را انتخاب کنید که از VPN استفاده نکنند';

  @override
  String get appRoutingPickOnly =>
      'اپ‌هایی را انتخاب کنید که از VPN استفاده کنند';

  @override
  String appRoutingThroughVpn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString اپ از طریق VPN',
      one: '$countString اپ از طریق VPN',
    );
    return '$_temp0';
  }

  @override
  String appRoutingDirect(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString اپ مستقیم',
      one: '$countString اپ مستقیم',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingTagVpn => 'VPN';

  @override
  String get appRoutingTagDirect => 'مستقیم';

  @override
  String get dnsServerTitle => 'سرور دی‌اِن‌اِس';

  @override
  String dnsServerCurrent(String dns) {
    return 'فعلی: $dns';
  }

  @override
  String get proxyOnlyTitle => 'حالت فقط پروکسی';

  @override
  String proxyOnlyEnabled(int port) {
    return 'استفاده از پروکسی SOCKS روی پورت $port';
  }

  @override
  String get proxyOnlyDisabled => 'استفاده از پروکسی به‌جای VPN';

  @override
  String get connectionModeTunnel => 'تونل';

  @override
  String get connectionModeTunnelHint =>
      'همه‌ی برنامه‌ها از بگذر رد می‌شوند. ویندوز هر بار که وصل می‌شوید اجازه‌ی مدیر را می‌پرسد.';

  @override
  String get connectionModeSystemProxy => 'پروکسی سیستم';

  @override
  String connectionModeSystemProxyHint(int port) {
    return 'برنامه‌هایی که از تنظیمات پروکسی ویندوز پیروی می‌کنند از 127.0.0.1:$port استفاده می‌کنند';
  }

  @override
  String get connectionModeProxyOnly => 'فقط پروکسی';

  @override
  String connectionModeProxyOnlyHint(int port) {
    return 'برنامه‌ها را خودتان روی پورت SOCKS $port تنظیم کنید';
  }

  @override
  String get bypassLanTitle => 'Bypass LAN';

  @override
  String get bypassLanEnabled =>
      'SOCKS روی همه اینترفیس‌ها گوش می‌دهد (0.0.0.0)';

  @override
  String get bypassLanDisabled =>
      'دستگاه‌های دیگر شبکه بتوانند از این پروکسی استفاده کنند';

  @override
  String get bypassLanRequiresProxy =>
      'برای Bypass LAN باید حالت فقط پروکسی روشن باشد';

  @override
  String get bypassLanRequiresProxyMode =>
      'برای Bypass LAN، «فقط پروکسی» را انتخاب کنید';

  @override
  String get bypassLanAddressesTitle => 'آدرس‌های دستگاه';

  @override
  String get bypassLanNoAddresses => 'آدرس LAN پیدا نشد';

  @override
  String bypassLanEndpoint(String ip, int port) {
    return 'socks5://$ip:$port';
  }

  @override
  String get routingRulesTitle => 'قوانین سایت و IP';

  @override
  String get routingRulesSubtitle => 'مسیریابی یا مسدود کردن سایت‌ها و IPها';

  @override
  String routingRulesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString قانون سفارشی',
      one: '$countString قانون سفارشی',
    );
    return '$_temp0';
  }

  @override
  String get routingRulesScreenTitle => 'قوانین سایت و IP';

  @override
  String get routingRulesHint =>
      'قوانین سفارشی در اتصال بعدی اعمال می‌شوند. برای اعمال تغییرات VPN را دوباره وصل کنید.';

  @override
  String get routingTabDirect => 'مستقیم';

  @override
  String get routingTabBlock => 'مسدود';

  @override
  String get routingTabProxy => 'پروکسی';

  @override
  String get routingAddRule => 'افزودن قانون';

  @override
  String get routingEntryDomain => 'دامنه';

  @override
  String get routingEntryIp => 'IP';

  @override
  String get routingDomainHint => 'example.com';

  @override
  String get routingIpHint => '10.0.0.0/8 یا 8.8.8.8';

  @override
  String get routingInvalidInput => 'دامنه یا IP نامعتبر است';

  @override
  String get routingEmptyDirect => 'هنوز مسیر مستقیمی نیست';

  @override
  String get routingAlreadyListed => 'این قانون از قبل در فهرست هست';

  @override
  String get routingEmptyBlock => 'هنوز مسیر مسدودی نیست';

  @override
  String get routingEmptyProxy => 'هنوز مسیر پروکسی نیست';

  @override
  String get settingsInfoReconnect =>
      'تغییرات پس از اتصال مجدد VPN اعمال می‌شوند';

  @override
  String get dnsDialogTitle => 'سرور دی‌اِن‌اِس';

  @override
  String get dnsDialogPrompt => 'آدرس IP سرور دی‌اِن‌اِس را وارد کنید:';

  @override
  String get dnsDialogCommon => 'سرورهای دی‌اِن‌اِس رایج:';

  @override
  String get dnsDialogInvalid => 'یک آدرس IP وارد کنید، مانند 8.8.8.8';

  @override
  String get languageDialogTitle => 'انتخاب زبان';

  @override
  String get languageChoiceHint =>
      'بعداً می‌توانید آن را در تنظیمات تغییر دهید';

  @override
  String get languageContinue => 'ادامه';

  @override
  String dnsChipLabel(String label, String dns) {
    return '$label ($dns)';
  }

  @override
  String get dnsGoogle => 'گوگل';

  @override
  String get dnsCloudflare => 'کلودفلر';

  @override
  String get dnsLevel3 => 'Level3';

  @override
  String get dnsOpenDns => 'OpenDNS';

  @override
  String get clearAll => 'پاک کردن همه';

  @override
  String get searchAppsHint => 'جستجوی اپ‌ها...';

  @override
  String get noAppsFound => 'اپی یافت نشد';

  @override
  String get noSearchResults => 'نتیجه‌ای نیست';

  @override
  String get premiumHeroTitle => 'بگذر پریمیوم';

  @override
  String get premiumHeroSubtitle =>
      'برای دسترسی به سرورهای پریمیوم وارد شوید و اشتراک را مدیریت کنید';

  @override
  String get signInToPremium => 'ورود به پریمیوم';

  @override
  String get usePremiumCredentials =>
      'از اطلاعات حساب پریمیوم خود استفاده کنید';

  @override
  String get password => 'رمز عبور';

  @override
  String get signIn => 'ورود';

  @override
  String get signingIn => 'در حال ورود...';

  @override
  String get emailOrUsername => 'ایمیل یا نام کاربری';

  @override
  String get createAccountLink => 'حساب ندارید؟ بسازید';

  @override
  String get signInLink => 'حساب دارید؟ وارد شوید';

  @override
  String get createAccountTitle => 'ساخت حساب';

  @override
  String get createAccountHint => 'کد تأیید را به ایمیل شما می‌فرستیم';

  @override
  String get email => 'ایمیل';

  @override
  String get confirmPassword => 'تکرار رمز عبور';

  @override
  String get createAccount => 'ساخت حساب';

  @override
  String get creatingAccount => 'در حال ساخت حساب...';

  @override
  String get signUpPrivacyNotice =>
      'با ساخت حساب، سیاست حریم خصوصی را می‌پذیرید';

  @override
  String get verifyEmailTitle => 'ایمیل خود را بررسی کنید';

  @override
  String get verifyEmailHint =>
      'کد ۶ رقمی ارسال‌شده به این ایمیل را وارد کنید:';

  @override
  String get confirmationCode => 'کد تأیید';

  @override
  String get confirmCode => 'تأیید';

  @override
  String get confirmingCode => 'در حال تأیید...';

  @override
  String get resendCode => 'ارسال دوباره‌ی کد';

  @override
  String resendCodeIn(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'ارسال دوباره تا $secondsString ثانیه‌ی دیگر',
      one: 'ارسال دوباره تا ۱ ثانیه‌ی دیگر',
    );
    return '$_temp0';
  }

  @override
  String get changeEmail => 'تغییر ایمیل';

  @override
  String get errEmailFormat => 'یک ایمیل معتبر وارد کنید';

  @override
  String errPasswordLength(int min) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);

    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'دست‌کم $minString کاراکتر وارد کنید',
      one: 'دست‌کم ۱ کاراکتر وارد کنید',
    );
    return '$_temp0';
  }

  @override
  String get errPasswordMismatch => 'رمزهای عبور یکسان نیستند';

  @override
  String get errCodeFormat => 'کد ۶ رقمی را وارد کنید';

  @override
  String get deleteAccount => 'حذف حساب';

  @override
  String get deleteAccountTitle => 'حساب شما حذف شود؟';

  @override
  String get deleteAccountMessage =>
      'حساب شما، دستگاه‌های متصل به آن و زمان باقی‌مانده‌ی اشتراک همین حالا حذف می‌شوند. این کار برگشت‌پذیر نیست.';

  @override
  String get deleteAccountPlayNote =>
      'حذف حساب، اشتراک گوگل پلی را لغو نمی‌کند.';

  @override
  String get manageGooglePlaySubscription => 'مدیریت در گوگل پلی';

  @override
  String get deleteAccountConfirm => 'حذف';

  @override
  String get deletingAccount => 'در حال حذف...';

  @override
  String get accountDeleted => 'حساب شما حذف شد';

  @override
  String paywallDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString دستگاه',
      one: '۱ دستگاه',
    );
    return '$_temp0';
  }

  @override
  String paywallMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ماه',
      one: '۱ ماه',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitle => 'ارتقا به پریمیوم';

  @override
  String get paywallCompareHeading => 'چه چیزی می‌گیرید';

  @override
  String get paywallRowAds => 'تبلیغ';

  @override
  String get paywallBasicAds => 'هر بار';

  @override
  String get paywallPremiumAds => 'ندارد';

  @override
  String get paywallRowCountry => 'کشور';

  @override
  String get paywallBasicCountry => 'خودکار';

  @override
  String get paywallIncluded => 'دارد';

  @override
  String get paywallRowServers => 'سرورها';

  @override
  String get paywallBasicServers => 'اشتراکی';

  @override
  String get paywallPremiumServers => 'حداکثر سرعت';

  @override
  String get paywallRowDevices => 'دستگاه‌ها';

  @override
  String get paywallNotIncluded => 'ندارد';

  @override
  String paywallPremiumDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تا $countString',
      one: '۱',
    );
    return '$_temp0';
  }

  @override
  String get paywallDevicesHint => 'به‌طور هم‌زمان';

  @override
  String get paywallFewerDevices => 'دستگاه کمتر';

  @override
  String get paywallMoreDevices => 'دستگاه بیشتر';

  @override
  String paywallPerMonth(String price) {
    return 'ماهی $price';
  }

  @override
  String paywallSave(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$percentString٪ صرفه‌جویی';
  }

  @override
  String get paywallBestValue => 'به‌صرفه‌ترین';

  @override
  String paywallContinue(String period, String price, int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.selectLogic(period, {
      'month': 'ادامه — ماهی $price',
      'year': 'ادامه — سالی $price',
      'other': 'ادامه — $price برای $monthsString ماه',
    });
    return '$_temp0';
  }

  @override
  String get subscriptionAutoRenews =>
      'اشتراک به‌طور خودکار تمدید می‌شود. هر زمان بخواهید می‌توانید آن را در گوگل پلی لغو کنید.';

  @override
  String get paymentProblemsLink => 'در پرداخت مشکل دارید؟';

  @override
  String get purchasePending =>
      'پرداخت شما در انتظار تأیید است. پریمیوم پس از تأیید گوگل پلی فعال می‌شود.';

  @override
  String get purchaseConfirmLater =>
      'پرداخت انجام شد. پریمیوم به‌محض تأیید ما فعال می‌شود.';

  @override
  String get purchaseGranted => 'پریمیوم فعال شد';

  @override
  String get signInToSubscribe => 'برای خرید اشتراک وارد شوید یا حساب بسازید';

  @override
  String get premiumActive => 'پریمیوم فعال';

  @override
  String get premiumAccountInactive => 'اکانت غیرفعال';

  @override
  String get premiumNoSubscription => 'هنوز اشتراکی ندارید';

  @override
  String get premiumNoSubscriptionHint =>
      'پریمیوم سرورهای سریع‌تر و بدون تبلیغ را باز می‌کند. بعد از خرید، «بروزرسانی» را بزنید.';

  @override
  String get premiumNoSubscriptionHintDesktop =>
      'پریمیوم سرورهای سریع‌تر و بدون تبلیغ را باز می‌کند. بعد از خرید، روی «بروزرسانی» کلیک کنید.';

  @override
  String get premiumExpiredHint =>
      'اشتراک شما تمام شده است. برای استفاده دوباره از سرورهای پریمیوم، آن را تمدید کنید.';

  @override
  String get premiumInactiveHint =>
      'این حساب غیرفعال شده است. برای فعال‌سازی دوباره با پشتیبانی تماس بگیرید.';

  @override
  String get premiumPerkServers => 'سرورهای پریمیوم';

  @override
  String get planFree => 'رایگان';

  @override
  String get premiumPerkStaticIp => 'آی‌پی ثابت';

  @override
  String get premiumPerkNoAds => 'بدون تبلیغات';

  @override
  String get homeFactMode => 'حالت';

  @override
  String get homeFactDns => 'دی‌اِن‌اِس';

  @override
  String get homeFactApps => 'برنامه‌ها';

  @override
  String get homeModeVpn => 'VPN';

  @override
  String get homeSupport => 'پشتیبانی';

  @override
  String get navSettings => 'تنظیمات';

  @override
  String get navHome => 'خانه';

  @override
  String get navPremium => 'پریمیوم';

  @override
  String get homeAppsAll => 'همهٔ برنامه‌ها';

  @override
  String homeAppsExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'همه جز  $countString';
  }

  @override
  String homeAppsOnly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'فقط $countString';
  }

  @override
  String get expires => 'انقضا';

  @override
  String get remaining => 'روز باقی‌مانده';

  @override
  String get accountStatus => 'وضعیت اکانت';

  @override
  String get userStatusActive => 'فعال';

  @override
  String get userStatusExpired => 'منقضی';

  @override
  String get userStatusInactive => 'غیرفعال';

  @override
  String get userStatusDisabled => 'غیرفعال';

  @override
  String get userStatusSuspended => 'معلق';

  @override
  String get userStatusBanned => 'مسدود';

  @override
  String get expired => 'منقضی شده';

  @override
  String get refresh => 'بروزرسانی';

  @override
  String get signOut => 'خروج';

  @override
  String get signingOut => 'در حال خروج...';

  @override
  String get deviceBindingInfo =>
      'حساب شما به این دستگاه متصل است. کانفیگ‌های پریمیوم با قفل دستگاه محافظت می‌شوند.';

  @override
  String get linkedDevices => 'دستگاه‌های متصل';

  @override
  String get linkedDevicesHint => 'در حال بارگذاری دستگاه‌ها...';

  @override
  String devicesCount(int active, int max) {
    final intl.NumberFormat activeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String activeString = activeNumberFormat.format(active);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$activeString از $maxString دستگاه';
  }

  @override
  String get noLinkedDevices => 'دستگاه متصلی یافت نشد';

  @override
  String get thisDevice => 'این دستگاه';

  @override
  String deviceLoggedInAt(String date) {
    return 'ورود: $date';
  }

  @override
  String get removeDevice => 'حذف';

  @override
  String get removeDeviceTitle => 'حذف دستگاه';

  @override
  String removeDeviceMessage(String name) {
    return '«$name» از حساب پریمیوم حذف شود؟ بلافاصله از حساب خارج می‌شود.';
  }

  @override
  String get deviceRemovedSuccess => 'دستگاه با موفقیت حذف شد';

  @override
  String get tryAgain => 'تلاش مجدد';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get tunnelStalledTitle => 'ترافیکی رد نمی‌شود';

  @override
  String get tunnelStalledHint => 'این سرور دیگر جواب نمی‌دهد';

  @override
  String get tunnelStalledSwitch => 'تعویض سرور';

  @override
  String get notifTunnelTitle => 'بگذر متصل است';

  @override
  String get notifTunnelVpnMode => 'حالت VPN';

  @override
  String get notifTunnelProxyMode => 'حالت پروکسی';

  @override
  String get notifTunnelChannelName => 'اتصال';

  @override
  String get notifTunnelChannelDescription =>
      'تا زمانی که تونل برقرار است نمایش داده می‌شود';

  @override
  String get premiumServersTitle => 'سرورهای پریمیوم';

  @override
  String get premiumServersSubtitle => 'یک سرور برای اتصال انتخاب کنید';

  @override
  String get premiumServersConnectedHint =>
      'برای قطع اتصال، روی سرور متصل ضربه بزنید';

  @override
  String get premiumServersConnectedHintDesktop =>
      'برای قطع اتصال، روی سرور متصل کلیک کنید';

  @override
  String get lastConnected => 'آخرین اتصال';

  @override
  String get configConnected => 'متصل';

  @override
  String get premiumServersEmpty => 'سرور پریمیومی در دسترس نیست';

  @override
  String premiumServerConfigsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString کانفیگ';
  }

  @override
  String get serverRowChoose => 'یک سرور انتخاب کنید';

  @override
  String get serverRowChooseHint => 'برای دیدن سرورهای موجود ضربه بزنید';

  @override
  String get serverRowChooseHintDesktop => 'برای دیدن سرورهای موجود کلیک کنید';

  @override
  String get serverRowWithdrawn => 'حذف شده · سرور دیگری انتخاب کنید';

  @override
  String get serverRowPremium => 'سرورهای پریمیوم';

  @override
  String get serverRowPremiumHint => 'کشور دلخواهت را انتخاب کن، بدون تبلیغات';

  @override
  String get serverRowExpired => 'اشتراک منقضی شده';

  @override
  String get serverRowExpiredHint => 'برای انتخاب سرور، اشتراک را تمدید کنید';

  @override
  String get serverRowInactive => 'حساب غیرفعال شده';

  @override
  String get serverRowInactiveHint => 'برای فعال‌سازی با پشتیبانی تماس بگیرید';

  @override
  String get notificationPermissionTitle => 'دسترسی اعلان لازم است';

  @override
  String get notificationPermissionMessage =>
      'برای استفاده از بگذر باید اعلان‌ها فعال باشند تا از به‌روزرسانی‌ها و پیام‌های مهم مطلع شوید.';

  @override
  String get enableNotifications => 'فعال‌سازی اعلان‌ها';

  @override
  String get openNotificationSettings => 'باز کردن تنظیمات';

  @override
  String get notificationPermissionSettingsHint =>
      'اعلان‌ها غیرفعال است. برای ادامه، آن را در تنظیمات دستگاه فعال کنید.';

  @override
  String get macOsPermissionsTitle => 'دسترسی‌های لازم';

  @override
  String get macOsPermissionsMessage =>
      'بگذر روی مک به ذخیره امن و پروکسی سیستم نیاز دارد. هر دو را بدهید تا ادامه دهید.';

  @override
  String get macOsPermissionSecureStorage => 'ذخیره امن';

  @override
  String get macOsPermissionSecureStorageHint =>
      'کلید دستگاه و اطلاعات حساب را به‌صورت امن نگه می‌دارد.';

  @override
  String get macOsPermissionSystemProxy => 'پروکسی سیستم';

  @override
  String get macOsPermissionSystemProxyHint =>
      'ترافیک مرورگر و برنامه‌ها را از طریق بگذر هدایت می‌کند.';

  @override
  String get macOsPermissionGrant => 'اجازه بده';

  @override
  String get macOsPermissionGrantAll => 'اجازه همه دسترسی‌ها';

  @override
  String get macOsPermissionContinue => 'ادامه';

  @override
  String get macOsPermissionsBlockedHint =>
      'تا وقتی هر دو دسترسی داده نشود، نمی‌توانید از برنامه استفاده کنید.';

  @override
  String get updateRequired => 'به‌روزرسانی الزامی';

  @override
  String get updateDescription =>
      'نسخه جدید برنامه موجود است. لطفاً برای ادامه استفاده به‌روزرسانی کنید.';

  @override
  String get currentVersion => 'نسخه فعلی';

  @override
  String get requiredVersion => 'نسخه مورد نیاز';

  @override
  String get updateNow => 'هم‌اکنون به‌روزرسانی';

  @override
  String get updateOpenFailed =>
      'صفحه به‌روزرسانی باز نشد. لطفاً دستی به فروشگاه مراجعه کنید.';

  @override
  String updateError(String e) {
    return 'خطا در باز کردن صفحه به‌روزرسانی: $e';
  }

  @override
  String get updateAvailableTitle => 'نسخه جدید موجود است';

  @override
  String updateAvailableVersions(String latest, String installed) {
    return 'نسخه جدید $latest · نسخه شما $installed';
  }

  @override
  String get adBadge => 'تبلیغ';

  @override
  String adCloseCountdown(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return 'تا $secondsString ثانیه دیگر می‌توانید ببندید';
  }

  @override
  String adCloseSeconds(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString';
  }

  @override
  String get adSkipWarningTitle => 'اتصال قطع شد';

  @override
  String get adSkipWarningMessage =>
      'اتصال شما قطع شد چون تبلیغ را تا انتها مشاهده نکردید. برای حذف تبلیغات، نسخه پریمیوم تهیه کنید.';

  @override
  String get close => 'بستن';

  @override
  String get linkOpenFailed => 'نمی‌توان لینک را باز کرد';

  @override
  String get errSubscriptionRequired =>
      'ابتدا با اشتراک پریمیوم فعال وارد شوید';

  @override
  String get errCredentialsRequired => 'نام کاربری و رمز عبور الزامی است';

  @override
  String loginFailed(String e) {
    return 'ورود ناموفق: $e';
  }

  @override
  String get errRefreshFailed => 'بروزرسانی اشتراک ناموفق بود';

  @override
  String get errSignOutFailed => 'خروج ناموفق بود. دوباره تلاش کنید.';

  @override
  String get errLoginFailed => 'ورود ناموفق';

  @override
  String get errLoadSubscription => 'بارگذاری اشتراک ناموفق بود';

  @override
  String get errLogoutFailed => 'خروج ناموفق';

  @override
  String get errSessionNotFound => 'نشست پریمیوم یافت نشد. دوباره وارد شوید.';

  @override
  String get errUnexpectedConfigs => 'پاسخ غیرمنتظره از سرور کانفیگ پریمیوم';

  @override
  String get errConfigsRequestFailed => 'درخواست کانفیگ پریمیوم ناموفق بود';

  @override
  String get errNoConfigsFound =>
      'کانفیگ پریمیومی یافت نشد (رمزگشایی یا پارس ناموفق)';

  @override
  String loadConfigsFailed(String e) {
    return 'بارگذاری کانفیگ پریمیوم ناموفق: $e';
  }

  @override
  String loadDevicesFailed(String e) {
    return 'بارگذاری دستگاه‌ها ناموفق: $e';
  }

  @override
  String loadPremiumServersFailed(String e) {
    return 'بارگذاری سرورهای پریمیوم ناموفق: $e';
  }

  @override
  String removeDeviceFailed(String e) {
    return 'حذف دستگاه ناموفق: $e';
  }

  @override
  String get errLoadDevices => 'بارگذاری دستگاه‌ها ناموفق بود';

  @override
  String get errLoadPremiumServers => 'بارگذاری سرورهای پریمیوم ناموفق بود';

  @override
  String get errRemoveDevice => 'حذف دستگاه ناموفق بود';

  @override
  String get errDeviceNotFound => 'دستگاه یافت نشد';

  @override
  String get errInvalidCredentials => 'نام کاربری یا رمز عبور نامعتبر';

  @override
  String get errDeviceBound => 'این حساب به دستگاه دیگری متصل است';

  @override
  String get errTooManyAttempts =>
      'تلاش‌های زیاد. لطفاً بعداً دوباره امتحان کنید';

  @override
  String get errEmailTaken => 'حسابی با این ایمیل وجود دارد';

  @override
  String get errWrongPassword => 'رمز عبور درست نیست';

  @override
  String get errPasswordRequired => 'رمز عبور خود را وارد کنید';

  @override
  String get errCodeInvalid => 'کد وارد شده درست نیست';

  @override
  String get errCodeExpired => 'کد منقضی شده است. کد جدید بگیرید';

  @override
  String get errSignUpFailed => 'ساخت حساب ناموفق بود';

  @override
  String get errVerifyFailed => 'تأیید کد ناموفق بود';

  @override
  String get errDeleteAccountFailed => 'حذف حساب ناموفق بود';

  @override
  String get errPlansUnavailable =>
      'بارگذاری پلن‌ها ممکن نشد. بعداً دوباره امتحان کنید';

  @override
  String get errPurchaseFailed => 'خرید انجام نشد';

  @override
  String get errPlayAlreadyOwned =>
      'این حساب گوگل از قبل اشتراک بگذر دارد. با حسابی که آن را خریده وارد شوید';

  @override
  String get errRateLimit =>
      'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید';

  @override
  String get errAccessDenied =>
      'دسترسی رد شد. دوباره وارد شوید یا با پشتیبانی تماس بگیرید';

  @override
  String get errNoResponse => 'پاسخی از سرور دریافت نشد';

  @override
  String get errNoStorageAccess => 'دسترسی به ذخیره‌سازی وجود ندارد';

  @override
  String get errEngineLogUnavailable => 'گزارش موتور خوانده نشد';

  @override
  String get errEngineMissing =>
      'این نسخه موتور بگذر را ندارد و نمی‌تواند وصل شود';

  @override
  String get engineLogTitle => 'گزارش موتور';

  @override
  String get engineLogAll => 'همه';

  @override
  String get engineLogEngine => 'موتور';

  @override
  String get engineLogClear => 'پاک کردن';

  @override
  String get engineLogExport => 'خروجی گرفتن';

  @override
  String get engineLogEmpty => 'هنوز چیزی ثبت نشده است';

  @override
  String get engineLogDropped => 'خط‌های قدیمی‌تر حذف شدند';

  @override
  String get engineLogSaved => 'گزارش ذخیره شد';

  @override
  String get engineLogClose => 'بستن';

  @override
  String get errConnectionTimeout => 'اتصال منقضی شد. دوباره تلاش کنید';

  @override
  String get errNetworkError => 'خطای شبکه. اتصال اینترنت را بررسی کنید';

  @override
  String get errNoConfigsFromServer => 'هیچ سروری از سرویس دریافت نشد';

  @override
  String get errNoConfigsAvailable => 'سروری برای اتصال موجود نیست';

  @override
  String get errNoWorkingConfig =>
      'سروری برای اتصال پیدا نشد. بعداً دوباره تلاش کنید';

  @override
  String get errApiV2Unavailable => 'سرویس اتصال در دسترس نیست';

  @override
  String get errPremiumApiUnavailable => 'سرویس پریمیوم در دسترس نیست';

  @override
  String get errProxyTestFailed => 'اتصال به هیچ سروری برقرار نشد';

  @override
  String get errInvalidConfig => 'تنظیمات سرور نامعتبر است';

  @override
  String get errDisconnectFailed => 'قطع اتصال ناموفق بود';

  @override
  String get errConnectionFailed => 'اتصال ناموفق بود. دوباره تلاش کنید';

  @override
  String get errElevationDeclined =>
      'حالت تونل به اجازه‌ی مدیر نیاز دارد. وقتی ویندوز پرسید اجازه دهید، یا در تنظیمات پروکسی سیستم را انتخاب کنید.';

  @override
  String get errTunnelUnavailable =>
      'حالت تونل شروع نشد. دوباره تلاش کنید، یا در تنظیمات پروکسی سیستم را انتخاب کنید.';

  @override
  String get errTunnelStopped => 'تونل متوقف شد. دوباره وصل شوید.';

  @override
  String get errUnauthorized => 'نشست منقضی شده. اپ را دوباره باز کنید';

  @override
  String get errForbidden => 'دسترسی به این سرویس مجاز نیست';

  @override
  String get errDeviceInitFailed => 'ثبت دستگاه روی سرور ناموفق بود';

  @override
  String get errFetchConfigsFailed => 'دریافت لیست سرورها ناموفق بود';

  @override
  String get errSecureConnectionFailed => 'اتصال امن به سرور برقرار نشد';

  @override
  String get errClockSkew => 'تاریخ یا ساعت این دستگاه اشتباه است';

  @override
  String get errClockSkewHint =>
      'تاریخ، ساعت و منطقه زمانی را روی حالت خودکار بگذارید و دوباره تلاش کنید';

  @override
  String get errRequestUnverified => 'امکان تأیید این درخواست وجود نداشت';

  @override
  String get errRequestUnverifiedHint =>
      'اپ را کاملاً ببندید و دوباره باز کنید';

  @override
  String get errReplayDetected => 'این درخواست قبلاً استفاده شده است';

  @override
  String get errReplayDetectedHint => 'کمی صبر کنید و دوباره تلاش کنید';

  @override
  String get errIpBlocked => 'این شبکه نمی‌تواند نشست جدید بسازد';

  @override
  String get errIpBlockedHint => 'به شبکه دیگری وصل شوید یا تا فردا صبر کنید';

  @override
  String get errMissingSession => 'این دستگاه روی سرور نشست ندارد';

  @override
  String get errMissingSessionHint =>
      'دوباره وصل شوید. اگر تکرار شد، اپ را کاملاً ببندید و دوباره تلاش کنید';

  @override
  String get errDeviceInitFailedHint =>
      'اتصال اینترنت را بررسی کنید و دوباره تلاش کنید';

  @override
  String get errInvalidCredentialsHint =>
      'اگر رمز را فراموش کرده‌اید، از ربات پریمیوم تغییرش دهید';

  @override
  String get errDeviceLimit => 'این حساب جای خالی برای دستگاه جدید ندارد';

  @override
  String get errDeviceLimitHint =>
      'دستگاه‌های ثبت‌شده را در ربات پریمیوم ریست کنید و دوباره وارد شوید';

  @override
  String get errDeviceNotRegistered => 'این دستگاه روی حساب ثبت نشده است';

  @override
  String get errDeviceNotRegisteredHint =>
      'خارج شوید و دوباره وارد شوید تا ثبت شود';

  @override
  String get errAccountDisabled => 'حساب شما غیرفعال شده است';

  @override
  String get errAccountDisabledHint => 'برای کمک با ربات پریمیوم تماس بگیرید';

  @override
  String get errAccountExpired => 'اشتراک پریمیوم شما منقضی شده است';

  @override
  String get errAccountExpiredHint => 'از ربات پریمیوم تمدیدش کنید';

  @override
  String get errRateLimitHint => 'یک دقیقه صبر کنید و دوباره تلاش کنید';

  @override
  String errRateLimitWait(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$nString ثانیه دیگر دوباره تلاش کنید';
  }

  @override
  String get errSessionCredentials => 'برای ادامه دوباره وارد شوید';

  @override
  String get errSessionCredentialsHint =>
      'اگر نمی‌توانید وارد شوید، رمز را در ربات پریمیوم عوض کنید';

  @override
  String get getHelp => 'دریافت راهنمایی';

  @override
  String daysLeft(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString روز',
      one: '$daysString روز',
    );
    return '$_temp0';
  }
}
