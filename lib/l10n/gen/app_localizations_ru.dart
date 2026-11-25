// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'BEGZAR';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get premium => 'Премиум';

  @override
  String get basic => 'Базовый';

  @override
  String get unknown => '-';

  @override
  String get planPremium => 'Премиум';

  @override
  String get planBasic => 'Базовый';

  @override
  String get premiumDialogTitle => 'Подписка Премиум';

  @override
  String get premiumDialogMessage =>
      'Войдите или купите Премиум для доступа к премиум-серверам.';

  @override
  String get buyPremium => 'Купить Премиум';

  @override
  String get subscriptionExpiredTitle => 'Подписка истекла';

  @override
  String get subscriptionExpiredMessage =>
      'Срок вашей Premium-подписки истёк. Продлите её, чтобы продолжить пользоваться premium-серверами.';

  @override
  String get renewSubscription => 'Продлить подписку';

  @override
  String get accountInactiveTitle => 'Аккаунт неактивен';

  @override
  String get accountInactiveMessage =>
      'Ваш аккаунт был деактивирован. Свяжитесь с поддержкой в Telegram.';

  @override
  String get otherVpnTurnedOff =>
      'На устройстве был подключён другой VPN, и Begzar отключил его.';

  @override
  String get otherVpnOnTitle => 'Включён другой VPN';

  @override
  String get otherVpnOnMessage =>
      'На этом устройстве подключён другой VPN, и Begzar не может его отключить. Отключите его в настройках VPN устройства и попробуйте снова.';

  @override
  String get otherVpnContinueAnyway => 'Всё равно продолжить';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get contactSupport => 'Связаться с поддержкой';

  @override
  String get accountInactiveSupportMessage =>
      'Здравствуйте, мой Premium-аккаунт деактивирован, нужна помощь.';

  @override
  String get premiumSupportMessage =>
      'Здравствуйте, я хочу купить подписку Begzar Premium.';

  @override
  String get conn_connecting => 'Подключение';

  @override
  String get conn_disconnecting => 'Отключение';

  @override
  String get conn_connected => 'Под защитой';

  @override
  String get conn_error => 'Не удалось подключиться';

  @override
  String get conn_ready => 'Без защиты';

  @override
  String get connSub_connecting => 'Нажмите, чтобы отменить';

  @override
  String get connSub_connectingDesktop => 'Щёлкните, чтобы отменить';

  @override
  String get connSub_disconnecting => 'Закрываем туннель';

  @override
  String get connSub_error => 'Нажмите, чтобы повторить';

  @override
  String get connSub_errorDesktop => 'Щёлкните, чтобы повторить';

  @override
  String get connSub_ready => 'Нажмите, чтобы подключиться автоматически';

  @override
  String get connSub_readyDesktop =>
      'Щёлкните, чтобы подключиться автоматически';

  @override
  String get locationUnavailable => 'Местоположение недоступно';

  @override
  String get tapToTest => 'Нажмите для теста';

  @override
  String get tapToTestDesktop => 'Щёлкните для теста';

  @override
  String get tapToRetry => 'Нажмите для повтора';

  @override
  String get tapToRetryDesktop => 'Щёлкните для повтора';

  @override
  String pingMs(int ms) {
    final intl.NumberFormat msNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String msString = msNumberFormat.format(ms);

    return '$msString мс';
  }

  @override
  String get pingExcellent => 'Отлично';

  @override
  String get pingGood => 'Хорошо';

  @override
  String get pingFair => 'Средне';

  @override
  String get pingPoor => 'Плохо';

  @override
  String get settingsCategoryApp => 'Приложение';

  @override
  String get settingsCategoryGeneral => 'Общие';

  @override
  String get settingsCategoryConnection => 'Подключение';

  @override
  String get settingsCategoryNetwork => 'Сеть';

  @override
  String get settingsCategoryExperimental => 'Экспериментальное';

  @override
  String get experimentalTitle => 'Экспериментальные настройки';

  @override
  String get experimentalEnabled =>
      'Бесплатное подключение идёт через Cloudflare WARP';

  @override
  String get experimentalDisabled =>
      'Бесплатное подключение идёт через серверы Begzar';

  @override
  String get warpModeTitle => 'Режим WARP';

  @override
  String get warpModeMasque => 'MASQUE';

  @override
  String get warpModeWarp => 'WireGuard';

  @override
  String get warpModeGool => 'WARP внутри WARP';

  @override
  String get warpModeMasquePsiphon => 'Psiphon через MASQUE';

  @override
  String get warpModePsiphon => 'Psiphon через WARP';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSubtitle => 'Изменить язык приложения';

  @override
  String get themeTitle => 'Тема';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get appRoutingTitle => 'Маршрутизация приложений';

  @override
  String get appRoutingSubtitleNone =>
      'Выберите, какие приложения используют VPN';

  @override
  String appRoutingSubtitleAllExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Все, кроме $countString приложения',
      many: 'Все, кроме $countString приложений',
      few: 'Все, кроме $countString приложений',
      one: 'Все, кроме $countString приложения',
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
      other: 'Только $countString приложения',
      many: 'Только $countString приложений',
      few: 'Только $countString приложения',
      one: 'Только $countString приложение',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingNeedsVpn =>
      'Отключите режим «Только прокси» для маршрутизации приложений';

  @override
  String get appRoutingModeAllExcept => 'Все приложения используют VPN, кроме…';

  @override
  String get appRoutingModeAllExceptHint =>
      'Весь трафик идёт через VPN. Выбранные приложения подключаются напрямую.';

  @override
  String get appRoutingModeOnly => 'Только некоторые приложения используют VPN';

  @override
  String get appRoutingModeOnlyHint =>
      'Через VPN идут только выбранные приложения. Если ничего не выбрано, через VPN идут все.';

  @override
  String get appRoutingPickAllExcept =>
      'Выберите приложения, которые не используют VPN';

  @override
  String get appRoutingPickOnly =>
      'Выберите приложения, которые используют VPN';

  @override
  String appRoutingThroughVpn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString приложения через VPN',
      many: '$countString приложений через VPN',
      few: '$countString приложения через VPN',
      one: '$countString приложение через VPN',
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
      other: '$countString приложения напрямую',
      many: '$countString приложений напрямую',
      few: '$countString приложения напрямую',
      one: '$countString приложение напрямую',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingTagVpn => 'VPN';

  @override
  String get appRoutingTagDirect => 'Напрямую';

  @override
  String get dnsServerTitle => 'DNS-сервер';

  @override
  String dnsServerCurrent(String dns) {
    return 'Текущий: $dns';
  }

  @override
  String get proxyOnlyTitle => 'Только прокси';

  @override
  String proxyOnlyEnabled(int port) {
    return 'SOCKS-прокси на порту $port';
  }

  @override
  String get proxyOnlyDisabled => 'Использовать прокси вместо VPN';

  @override
  String get connectionModeTunnel => 'Туннель';

  @override
  String get connectionModeTunnelHint =>
      'Весь трафик приложений идёт через Begzar. Windows запрашивает права администратора при каждом подключении.';

  @override
  String get connectionModeSystemProxy => 'Системный прокси';

  @override
  String connectionModeSystemProxyHint(int port) {
    return 'Приложения, которые следуют настройкам прокси Windows, используют 127.0.0.1:$port';
  }

  @override
  String get connectionModeProxyOnly => 'Только прокси';

  @override
  String connectionModeProxyOnlyHint(int port) {
    return 'Направьте приложения на SOCKS-порт $port сами';
  }

  @override
  String get bypassLanTitle => 'Bypass LAN';

  @override
  String get bypassLanEnabled => 'SOCKS слушает на всех интерфейсах (0.0.0.0)';

  @override
  String get bypassLanDisabled =>
      'Разрешить устройствам в сети использовать этот прокси';

  @override
  String get bypassLanRequiresProxy =>
      'Включите режим «Только прокси» для Bypass LAN';

  @override
  String get bypassLanRequiresProxyMode =>
      'Выберите «Только прокси» для Bypass LAN';

  @override
  String get bypassLanAddressesTitle => 'Адреса устройства';

  @override
  String get bypassLanNoAddresses => 'LAN-адрес не найден';

  @override
  String bypassLanEndpoint(String ip, int port) {
    return 'socks5://$ip:$port';
  }

  @override
  String get routingRulesTitle => 'Правила для сайтов и IP';

  @override
  String get routingRulesSubtitle => 'Маршрутизация и блокировка сайтов и IP';

  @override
  String routingRulesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString пользовательского правила',
      many: '$countString пользовательских правил',
      few: '$countString пользовательских правила',
      one: '$countString пользовательское правило',
    );
    return '$_temp0';
  }

  @override
  String get routingRulesScreenTitle => 'Правила для сайтов и IP';

  @override
  String get routingRulesHint =>
      'Пользовательские правила применяются при следующем подключении. Переподключите VPN.';

  @override
  String get routingTabDirect => 'Напрямую';

  @override
  String get routingTabBlock => 'Блокировка';

  @override
  String get routingTabProxy => 'Прокси';

  @override
  String get routingAddRule => 'Добавить правило';

  @override
  String get routingEntryDomain => 'Домен';

  @override
  String get routingEntryIp => 'IP';

  @override
  String get routingDomainHint => 'example.com';

  @override
  String get routingIpHint => '10.0.0.0/8 или 8.8.8.8';

  @override
  String get routingInvalidInput => 'Неверный домен или IP';

  @override
  String get routingEmptyDirect => 'Нет правил «Напрямую»';

  @override
  String get routingAlreadyListed => 'Это правило уже есть в списке';

  @override
  String get routingEmptyBlock => 'Нет правил «Блокировка»';

  @override
  String get routingEmptyProxy => 'Нет правил «Прокси»';

  @override
  String get settingsInfoReconnect =>
      'Изменения применятся после переподключения VPN';

  @override
  String get dnsDialogTitle => 'DNS-сервер';

  @override
  String get dnsDialogPrompt => 'Введите IP-адрес DNS-сервера:';

  @override
  String get dnsDialogCommon => 'Популярные DNS-серверы:';

  @override
  String get dnsDialogInvalid => 'Введите IP-адрес, например 8.8.8.8';

  @override
  String get languageDialogTitle => 'Выберите язык';

  @override
  String get languageChoiceHint => 'Это можно изменить позже в настройках';

  @override
  String get languageContinue => 'Продолжить';

  @override
  String dnsChipLabel(String label, String dns) {
    return '$label ($dns)';
  }

  @override
  String get dnsGoogle => 'Google';

  @override
  String get dnsCloudflare => 'Cloudflare';

  @override
  String get dnsLevel3 => 'Level3';

  @override
  String get dnsOpenDns => 'OpenDNS';

  @override
  String get clearAll => 'Очистить всё';

  @override
  String get searchAppsHint => 'Поиск приложений...';

  @override
  String get noAppsFound => 'Приложения не найдены';

  @override
  String get noSearchResults => 'Нет результатов';

  @override
  String get premiumHeroTitle => 'Begzar Premium';

  @override
  String get premiumHeroSubtitle =>
      'Войдите для доступа к премиум-серверам и управления подпиской';

  @override
  String get signInToPremium => 'Вход в Премиум';

  @override
  String get usePremiumCredentials => 'Используйте данные премиум-аккаунта';

  @override
  String get password => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get signingIn => 'Вход...';

  @override
  String get emailOrUsername => 'Email или имя пользователя';

  @override
  String get createAccountLink => 'Нет аккаунта? Создайте';

  @override
  String get signInLink => 'Уже есть аккаунт? Войти';

  @override
  String get createAccountTitle => 'Создание аккаунта';

  @override
  String get createAccountHint => 'Мы отправим код подтверждения на вашу почту';

  @override
  String get email => 'Email';

  @override
  String get confirmPassword => 'Повторите пароль';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get creatingAccount => 'Создание...';

  @override
  String get signUpPrivacyNotice =>
      'Создавая аккаунт, вы принимаете политику конфиденциальности';

  @override
  String get verifyEmailTitle => 'Проверьте почту';

  @override
  String get verifyEmailHint => 'Введите 6-значный код, отправленный на адрес:';

  @override
  String get confirmationCode => 'Код';

  @override
  String get confirmCode => 'Подтвердить';

  @override
  String get confirmingCode => 'Подтверждение...';

  @override
  String get resendCode => 'Отправить снова';

  @override
  String resendCodeIn(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Повтор через $secondsString секунды',
      many: 'Повтор через $secondsString секунд',
      few: 'Повтор через $secondsString секунды',
      one: 'Повтор через $secondsString секунду',
    );
    return '$_temp0';
  }

  @override
  String get changeEmail => 'Изменить email';

  @override
  String get errEmailFormat => 'Введите корректный email';

  @override
  String errPasswordLength(int min) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);

    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'Минимум $minString символа',
      many: 'Минимум $minString символов',
      few: 'Минимум $minString символа',
      one: 'Минимум $minString символ',
    );
    return '$_temp0';
  }

  @override
  String get errPasswordMismatch => 'Пароли не совпадают';

  @override
  String get errCodeFormat => 'Введите 6-значный код';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountTitle => 'Удалить аккаунт?';

  @override
  String get deleteAccountMessage =>
      'Аккаунт, привязанные устройства и оставшееся оплаченное время будут удалены сразу. Это нельзя отменить.';

  @override
  String get deleteAccountPlayNote =>
      'Удаление аккаунта не отменяет подписку в Google Play.';

  @override
  String get manageGooglePlaySubscription => 'Управлять в Google Play';

  @override
  String get deleteAccountConfirm => 'Удалить';

  @override
  String get deletingAccount => 'Удаление...';

  @override
  String get accountDeleted => 'Аккаунт удалён';

  @override
  String paywallDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString устройства',
      many: '$countString устройств',
      few: '$countString устройства',
      one: '$countString устройство',
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
      other: '$countString месяца',
      many: '$countString месяцев',
      few: '$countString месяца',
      one: '$countString месяц',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitle => 'Перейти на Премиум';

  @override
  String get paywallCompareHeading => 'Что вы получаете';

  @override
  String get paywallRowAds => 'Реклама';

  @override
  String get paywallBasicAds => 'Каждый раз';

  @override
  String get paywallPremiumAds => 'Нет';

  @override
  String get paywallRowCountry => 'Страна';

  @override
  String get paywallBasicCountry => 'Автоматически';

  @override
  String get paywallIncluded => 'Есть';

  @override
  String get paywallRowServers => 'Серверы';

  @override
  String get paywallBasicServers => 'Общие';

  @override
  String get paywallPremiumServers => 'Полная скорость';

  @override
  String get paywallRowDevices => 'Устройства';

  @override
  String get paywallNotIncluded => 'Нет';

  @override
  String paywallPremiumDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'До $countString',
      one: '1',
    );
    return '$_temp0';
  }

  @override
  String get paywallDevicesHint => 'Одновременно';

  @override
  String get paywallFewerDevices => 'Меньше устройств';

  @override
  String get paywallMoreDevices => 'Больше устройств';

  @override
  String paywallPerMonth(String price) {
    return '$price / мес.';
  }

  @override
  String paywallSave(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Экономия $percentString%';
  }

  @override
  String get paywallBestValue => 'Выгоднее всего';

  @override
  String paywallContinue(String period, String price, int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.selectLogic(period, {
      'month': 'Продолжить — $price в месяц',
      'year': 'Продолжить — $price в год',
      'other': 'Продолжить — $price за $monthsString мес.',
    });
    return '$_temp0';
  }

  @override
  String get subscriptionAutoRenews =>
      'Подписка продлевается автоматически. Отменить её можно в любой момент в Google Play.';

  @override
  String get paymentProblemsLink => 'Проблемы с оплатой?';

  @override
  String get purchasePending =>
      'Платёж ожидает подтверждения. Премиум включится, как только Google Play его подтвердит.';

  @override
  String get purchaseConfirmLater =>
      'Оплата прошла. Премиум включится, как только мы её подтвердим.';

  @override
  String get purchaseGranted => 'Премиум активирован';

  @override
  String get signInToSubscribe =>
      'Войдите или создайте аккаунт, чтобы оформить подписку';

  @override
  String get premiumActive => 'Премиум активен';

  @override
  String get premiumAccountInactive => 'Аккаунт неактивен';

  @override
  String get premiumNoSubscription => 'Подписки пока нет';

  @override
  String get premiumNoSubscriptionHint =>
      'Премиум открывает быстрые серверы без рекламы. После покупки нажмите «Обновить».';

  @override
  String get premiumNoSubscriptionHintDesktop =>
      'Премиум открывает быстрые серверы без рекламы. После покупки щёлкните «Обновить».';

  @override
  String get premiumExpiredHint =>
      'Срок подписки истёк. Продлите её, чтобы снова пользоваться премиум-серверами.';

  @override
  String get premiumInactiveHint =>
      'Этот аккаунт отключён. Обратитесь в поддержку, чтобы восстановить его.';

  @override
  String get premiumPerkServers => 'Премиум-серверы';

  @override
  String get planFree => 'Бесплатно';

  @override
  String get premiumPerkStaticIp => 'Статический IP';

  @override
  String get premiumPerkNoAds => 'Без рекламы';

  @override
  String get homeFactMode => 'Режим';

  @override
  String get homeFactDns => 'DNS';

  @override
  String get homeFactApps => 'Приложения';

  @override
  String get homeModeVpn => 'VPN';

  @override
  String get homeSupport => 'Поддержка';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navHome => 'Главная';

  @override
  String get navPremium => 'Премиум';

  @override
  String get homeAppsAll => 'Все приложения';

  @override
  String homeAppsExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Все, кроме $countString';
  }

  @override
  String homeAppsOnly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Только $countString';
  }

  @override
  String get expires => 'Истекает';

  @override
  String get remaining => 'Осталось';

  @override
  String get accountStatus => 'Статус аккаунта';

  @override
  String get userStatusActive => 'Активен';

  @override
  String get userStatusExpired => 'Истёк';

  @override
  String get userStatusInactive => 'Неактивен';

  @override
  String get userStatusDisabled => 'Отключён';

  @override
  String get userStatusSuspended => 'Приостановлен';

  @override
  String get userStatusBanned => 'Заблокирован';

  @override
  String get expired => 'Истёк';

  @override
  String get refresh => 'Обновить';

  @override
  String get signOut => 'Выйти';

  @override
  String get signingOut => 'Выход...';

  @override
  String get deviceBindingInfo =>
      'Аккаунт привязан к этому устройству. Премиум-конфиги защищены привязкой к устройству.';

  @override
  String get linkedDevices => 'Привязанные устройства';

  @override
  String get linkedDevicesHint => 'Загрузка устройств...';

  @override
  String devicesCount(int active, int max) {
    final intl.NumberFormat activeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String activeString = activeNumberFormat.format(active);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$activeString из $maxString устройств';
  }

  @override
  String get noLinkedDevices => 'Привязанные устройства не найдены';

  @override
  String get thisDevice => 'Это устройство';

  @override
  String deviceLoggedInAt(String date) {
    return 'Вход: $date';
  }

  @override
  String get removeDevice => 'Удалить';

  @override
  String get removeDeviceTitle => 'Удалить устройство';

  @override
  String removeDeviceMessage(String name) {
    return 'Удалить «$name» из Premium-аккаунта? Устройство будет немедленно отключено.';
  }

  @override
  String get deviceRemovedSuccess => 'Устройство успешно удалено';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get tunnelStalledTitle => 'Трафик не проходит';

  @override
  String get tunnelStalledHint => 'Этот сервер перестал отвечать';

  @override
  String get tunnelStalledSwitch => 'Сменить сервер';

  @override
  String get notifTunnelTitle => 'Begzar подключён';

  @override
  String get notifTunnelVpnMode => 'Режим VPN';

  @override
  String get notifTunnelProxyMode => 'Режим прокси';

  @override
  String get notifTunnelChannelName => 'Подключение';

  @override
  String get notifTunnelChannelDescription =>
      'Отображается, пока туннель подключён';

  @override
  String get premiumServersTitle => 'Премиум-серверы';

  @override
  String get premiumServersSubtitle => 'Выберите сервер для подключения';

  @override
  String get premiumServersConnectedHint =>
      'Нажмите на подключённый сервер, чтобы отключить';

  @override
  String get premiumServersConnectedHintDesktop =>
      'Щёлкните по подключённому серверу, чтобы отключить';

  @override
  String get lastConnected => 'Последнее подключение';

  @override
  String get configConnected => 'Подключено';

  @override
  String get premiumServersEmpty => 'Нет доступных премиум-серверов';

  @override
  String premiumServerConfigsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString конфигов';
  }

  @override
  String get serverRowChoose => 'Выберите сервер';

  @override
  String get serverRowChooseHint => 'Нажмите, чтобы увидеть доступные';

  @override
  String get serverRowChooseHintDesktop => 'Щёлкните, чтобы увидеть доступные';

  @override
  String get serverRowWithdrawn => 'Удалён · выберите другой сервер';

  @override
  String get serverRowPremium => 'Премиум-серверы';

  @override
  String get serverRowPremiumHint => 'Свой город и без рекламы';

  @override
  String get serverRowExpired => 'Подписка истекла';

  @override
  String get serverRowExpiredHint => 'Продлите, чтобы снова выбирать сервер';

  @override
  String get serverRowInactive => 'Аккаунт отключён';

  @override
  String get serverRowInactiveHint =>
      'Обратитесь в поддержку для восстановления';

  @override
  String get notificationPermissionTitle =>
      'Требуется разрешение на уведомления';

  @override
  String get notificationPermissionMessage =>
      'Чтобы использовать Begzar, включите уведомления — так вы не пропустите важные обновления и сообщения.';

  @override
  String get enableNotifications => 'Включить уведомления';

  @override
  String get openNotificationSettings => 'Открыть настройки';

  @override
  String get notificationPermissionSettingsHint =>
      'Уведомления отключены. Включите их в настройках устройства, чтобы продолжить.';

  @override
  String get macOsPermissionsTitle => 'Требуются разрешения';

  @override
  String get macOsPermissionsMessage =>
      'На macOS Begzar нужен доступ к безопасному хранилищу и системному прокси. Выдайте оба, чтобы продолжить.';

  @override
  String get macOsPermissionSecureStorage => 'Безопасное хранилище';

  @override
  String get macOsPermissionSecureStorageHint =>
      'Надёжно хранит ключ устройства и данные аккаунта.';

  @override
  String get macOsPermissionSystemProxy => 'Системный прокси';

  @override
  String get macOsPermissionSystemProxyHint =>
      'Направляет трафик браузера и приложений через Begzar.';

  @override
  String get macOsPermissionGrant => 'Разрешить';

  @override
  String get macOsPermissionGrantAll => 'Разрешить все';

  @override
  String get macOsPermissionContinue => 'Продолжить';

  @override
  String get macOsPermissionsBlockedHint =>
      'Пока оба разрешения не выданы, пользоваться приложением нельзя.';

  @override
  String get updateRequired => 'Требуется обновление';

  @override
  String get updateDescription =>
      'Доступна новая версия. Обновите приложение для продолжения.';

  @override
  String get currentVersion => 'Текущая версия';

  @override
  String get requiredVersion => 'Требуемая версия';

  @override
  String get updateNow => 'Обновить';

  @override
  String get updateOpenFailed =>
      'Не удалось открыть страницу обновления. Перейдите в магазин вручную.';

  @override
  String updateError(String e) {
    return 'Ошибка открытия страницы обновления: $e';
  }

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String updateAvailableVersions(String latest, String installed) {
    return 'Новая версия $latest · у вас $installed';
  }

  @override
  String get adBadge => 'РЕКЛАМА';

  @override
  String adCloseCountdown(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return 'Закрыть через $secondsString с';
  }

  @override
  String adCloseSeconds(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString';
  }

  @override
  String get adSkipWarningTitle => 'Подключение разорвано';

  @override
  String get adSkipWarningMessage =>
      'Подключение разорвано, потому что вы не досмотрели рекламу. Купите Premium, чтобы убрать рекламу.';

  @override
  String get close => 'Закрыть';

  @override
  String get linkOpenFailed => 'Не удалось открыть ссылку';

  @override
  String get errSubscriptionRequired =>
      'Сначала войдите с активной подпиской Премиум';

  @override
  String get errCredentialsRequired => 'Требуются имя пользователя и пароль';

  @override
  String loginFailed(String e) {
    return 'Ошибка входа: $e';
  }

  @override
  String get errRefreshFailed => 'Не удалось обновить подписку';

  @override
  String get errSignOutFailed => 'Ошибка выхода. Попробуйте снова.';

  @override
  String get errLoginFailed => 'Ошибка входа';

  @override
  String get errLoadSubscription => 'Не удалось загрузить подписку';

  @override
  String get errLogoutFailed => 'Ошибка выхода';

  @override
  String get errSessionNotFound => 'Сессия Премиум не найдена. Войдите снова.';

  @override
  String get errUnexpectedConfigs => 'Неожиданный ответ премиум-конфигов';

  @override
  String get errConfigsRequestFailed => 'Ошибка запроса премиум-конфигов';

  @override
  String get errNoConfigsFound =>
      'Премиум-конфиги не найдены (ошибка расшифровки)';

  @override
  String loadConfigsFailed(String e) {
    return 'Ошибка загрузки премиум-конфигов: $e';
  }

  @override
  String loadDevicesFailed(String e) {
    return 'Ошибка загрузки устройств: $e';
  }

  @override
  String loadPremiumServersFailed(String e) {
    return 'Ошибка загрузки премиум-серверов: $e';
  }

  @override
  String removeDeviceFailed(String e) {
    return 'Ошибка удаления устройства: $e';
  }

  @override
  String get errLoadDevices => 'Не удалось загрузить устройства';

  @override
  String get errLoadPremiumServers => 'Не удалось загрузить премиум-серверы';

  @override
  String get errRemoveDevice => 'Не удалось удалить устройство';

  @override
  String get errDeviceNotFound => 'Устройство не найдено';

  @override
  String get errInvalidCredentials => 'Неверное имя пользователя или пароль';

  @override
  String get errDeviceBound => 'Аккаунт привязан к другому устройству';

  @override
  String get errTooManyAttempts => 'Слишком много попыток. Попробуйте позже';

  @override
  String get errEmailTaken => 'Аккаунт с этим адресом уже существует';

  @override
  String get errWrongPassword => 'Неверный пароль';

  @override
  String get errPasswordRequired => 'Введите пароль';

  @override
  String get errCodeInvalid => 'Неверный код';

  @override
  String get errCodeExpired => 'Срок действия кода истёк. Запросите новый';

  @override
  String get errSignUpFailed => 'Не удалось создать аккаунт';

  @override
  String get errVerifyFailed => 'Не удалось подтвердить код';

  @override
  String get errDeleteAccountFailed => 'Не удалось удалить аккаунт';

  @override
  String get errPlansUnavailable =>
      'Не удалось загрузить тарифы. Попробуйте позже';

  @override
  String get errPurchaseFailed => 'Покупка не прошла';

  @override
  String get errPlayAlreadyOwned =>
      'Этот аккаунт Google уже оплачивает подписку Begzar. Войдите в аккаунт, для которого она куплена';

  @override
  String get errRateLimit => 'Превышен лимит запросов';

  @override
  String get errAccessDenied => 'Доступ с сервера запрещён';

  @override
  String get errNoResponse => 'Нет ответа от сервера';

  @override
  String get errNoStorageAccess => 'Нет доступа к хранилищу';

  @override
  String get errEngineLogUnavailable => 'Не удалось прочитать журнал движка';

  @override
  String get errEngineMissing =>
      'В этой сборке нет движка Begzar, поэтому подключиться нельзя';

  @override
  String get engineLogTitle => 'Журнал движка';

  @override
  String get engineLogAll => 'Все';

  @override
  String get engineLogEngine => 'Движок';

  @override
  String get engineLogClear => 'Очистить';

  @override
  String get engineLogExport => 'Экспорт';

  @override
  String get engineLogEmpty => 'Пока ничего не записано';

  @override
  String get engineLogDropped => 'Старые строки удалены';

  @override
  String get engineLogSaved => 'Журнал сохранён';

  @override
  String get engineLogClose => 'Закрыть';

  @override
  String get errConnectionTimeout => 'Время ожидания истекло';

  @override
  String get errNetworkError => 'Ошибка сети';

  @override
  String get errNoConfigsFromServer => 'Сервер не вернул конфигурации';

  @override
  String get errNoConfigsAvailable => 'Нет доступных конфигураций';

  @override
  String get errNoWorkingConfig => 'Рабочая конфигурация не найдена';

  @override
  String get errApiV2Unavailable => 'Сервис подключения недоступен';

  @override
  String get errPremiumApiUnavailable => 'Premium-сервис недоступен';

  @override
  String get errProxyTestFailed => 'Проверка сервера не удалась';

  @override
  String get errInvalidConfig => 'Некорректная конфигурация прокси';

  @override
  String get errDisconnectFailed => 'Не удалось отключиться';

  @override
  String get errConnectionFailed => 'Ошибка подключения';

  @override
  String get errElevationDeclined =>
      'Режиму туннеля нужны права администратора. Разрешите их, когда Windows спросит, или выберите системный прокси в настройках.';

  @override
  String get errTunnelUnavailable =>
      'Не удалось запустить режим туннеля. Попробуйте снова или выберите системный прокси в настройках.';

  @override
  String get errTunnelStopped => 'Туннель остановился. Подключитесь снова.';

  @override
  String get errUnauthorized => 'Неавторизованный запрос';

  @override
  String get errForbidden => 'Доступ запрещён';

  @override
  String get errDeviceInitFailed => 'Не удалось инициализировать устройство';

  @override
  String get errFetchConfigsFailed =>
      'Не удалось получить конфигурации с сервера';

  @override
  String get errSecureConnectionFailed =>
      'Не удалось установить безопасное соединение с сервером';

  @override
  String get errClockSkew =>
      'Дата или время на этом устройстве указаны неверно';

  @override
  String get errClockSkewHint =>
      'Включите автоматические дату, время и часовой пояс и повторите попытку';

  @override
  String get errRequestUnverified => 'Не удалось проверить этот запрос';

  @override
  String get errRequestUnverifiedHint =>
      'Полностью закройте приложение и откройте его снова';

  @override
  String get errReplayDetected => 'Этот запрос уже был использован';

  @override
  String get errReplayDetectedHint => 'Подождите немного и повторите попытку';

  @override
  String get errIpBlocked => 'Эта сеть не может создать новую сессию';

  @override
  String get errIpBlockedHint =>
      'Подключитесь к другой сети или повторите попытку завтра';

  @override
  String get errMissingSession => 'У этого устройства нет сессии на сервере';

  @override
  String get errMissingSessionHint =>
      'Попробуйте подключиться снова. Если ошибка повторяется, полностью закройте приложение';

  @override
  String get errDeviceInitFailedHint =>
      'Проверьте интернет и повторите попытку';

  @override
  String get errInvalidCredentialsHint =>
      'Если вы забыли пароль, смените его в Premium-боте';

  @override
  String get errDeviceLimit =>
      'У этого аккаунта нет свободных слотов устройств';

  @override
  String get errDeviceLimitHint =>
      'Сбросьте зарегистрированные устройства в Premium-боте и войдите снова';

  @override
  String get errDeviceNotRegistered => 'Это устройство не привязано к аккаунту';

  @override
  String get errDeviceNotRegisteredHint =>
      'Выйдите и войдите снова, чтобы зарегистрировать устройство';

  @override
  String get errAccountDisabled => 'Ваш аккаунт деактивирован';

  @override
  String get errAccountDisabledHint => 'Обратитесь за помощью в Premium-бот';

  @override
  String get errAccountExpired => 'Срок вашей Premium-подписки истёк';

  @override
  String get errAccountExpiredHint => 'Продлите её в Premium-боте';

  @override
  String get errRateLimitHint => 'Подождите минуту и повторите попытку';

  @override
  String errRateLimitWait(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Повторите попытку через $nString с';
  }

  @override
  String get errSessionCredentials => 'Войдите снова, чтобы продолжить';

  @override
  String get errSessionCredentialsHint =>
      'Если не удаётся войти, смените пароль в Premium-боте';

  @override
  String get getHelp => 'Помощь';

  @override
  String daysLeft(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString дней',
      one: '$daysString день',
    );
    return '$_temp0';
  }
}
