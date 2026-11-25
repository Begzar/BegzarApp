// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'BEGZAR';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get premium => '高级版';

  @override
  String get basic => '基础版';

  @override
  String get unknown => '-';

  @override
  String get planPremium => '高级版';

  @override
  String get planBasic => '基础版';

  @override
  String get premiumDialogTitle => '高级版订阅';

  @override
  String get premiumDialogMessage => '登录或购买高级版以解锁高级服务器配置。';

  @override
  String get buyPremium => '购买高级版';

  @override
  String get subscriptionExpiredTitle => '订阅已过期';

  @override
  String get subscriptionExpiredMessage => '您的高级版订阅已过期。请续订以继续使用高级服务器。';

  @override
  String get renewSubscription => '续订订阅';

  @override
  String get accountInactiveTitle => '账户未激活';

  @override
  String get accountInactiveMessage => '您的账户已被停用。请联系 Telegram 客服。';

  @override
  String get otherVpnTurnedOff => '您的设备上连接了另一个 VPN，Begzar 已将其断开。';

  @override
  String get otherVpnOnTitle => '另一个 VPN 已开启';

  @override
  String get otherVpnOnMessage =>
      '此设备上已连接另一个 VPN，Begzar 无法将其关闭。请在设备的 VPN 设置中关闭它，然后重试。';

  @override
  String get otherVpnContinueAnyway => '仍然继续';

  @override
  String get openSettings => '打开设置';

  @override
  String get contactSupport => '联系客服';

  @override
  String get accountInactiveSupportMessage => '你好，我的高级版账户已被停用，需要帮助。';

  @override
  String get premiumSupportMessage => '你好，我想购买 Begzar 高级版订阅。';

  @override
  String get conn_connecting => '连接中';

  @override
  String get conn_disconnecting => '断开中';

  @override
  String get conn_connected => '已受保护';

  @override
  String get conn_error => '无法连接';

  @override
  String get conn_ready => '未受保护';

  @override
  String get connSub_connecting => '点按以取消';

  @override
  String get connSub_connectingDesktop => '点击以取消';

  @override
  String get connSub_disconnecting => '正在关闭隧道';

  @override
  String get connSub_error => '点按以重试';

  @override
  String get connSub_errorDesktop => '点击以重试';

  @override
  String get connSub_ready => '点按以自动连接';

  @override
  String get connSub_readyDesktop => '点击以自动连接';

  @override
  String get locationUnavailable => '位置不可用';

  @override
  String get tapToTest => '点按测试';

  @override
  String get tapToTestDesktop => '点击测试';

  @override
  String get tapToRetry => '点按重试';

  @override
  String get tapToRetryDesktop => '点击重试';

  @override
  String pingMs(int ms) {
    final intl.NumberFormat msNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String msString = msNumberFormat.format(ms);

    return '$msString毫秒';
  }

  @override
  String get pingExcellent => '极佳';

  @override
  String get pingGood => '良好';

  @override
  String get pingFair => '一般';

  @override
  String get pingPoor => '较差';

  @override
  String get settingsCategoryApp => '应用';

  @override
  String get settingsCategoryGeneral => '通用';

  @override
  String get settingsCategoryConnection => '连接';

  @override
  String get settingsCategoryNetwork => '网络';

  @override
  String get settingsCategoryExperimental => '实验性';

  @override
  String get experimentalTitle => '实验性设置';

  @override
  String get experimentalEnabled => '免费连接使用 Cloudflare WARP';

  @override
  String get experimentalDisabled => '免费连接使用 Begzar 服务器';

  @override
  String get warpModeTitle => 'WARP 模式';

  @override
  String get warpModeMasque => 'MASQUE';

  @override
  String get warpModeWarp => 'WireGuard';

  @override
  String get warpModeGool => 'WARP 嵌套 WARP';

  @override
  String get warpModeMasquePsiphon => '经 MASQUE 的 Psiphon';

  @override
  String get warpModePsiphon => '经 WARP 的 Psiphon';

  @override
  String get languageTitle => '语言';

  @override
  String get languageSubtitle => '更改应用语言';

  @override
  String get themeTitle => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get appRoutingTitle => '应用路由';

  @override
  String get appRoutingSubtitleNone => '选择哪些应用使用 VPN';

  @override
  String appRoutingSubtitleAllExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '除 $countString 个应用外均使用 VPN',
      one: '除 $countString 个应用外均使用 VPN',
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
      other: '仅 $countString 个应用',
      one: '仅 $countString 个应用',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingNeedsVpn => '请先关闭仅代理模式以使用应用路由';

  @override
  String get appRoutingModeAllExcept => '所有应用都使用 VPN，除了…';

  @override
  String get appRoutingModeAllExceptHint => '所有流量都经过 VPN。您选择的应用将直连。';

  @override
  String get appRoutingModeOnly => '仅部分应用使用 VPN';

  @override
  String get appRoutingModeOnlyHint => '只有您选择的应用经过 VPN。如未选择任何应用，则所有应用都经过 VPN。';

  @override
  String get appRoutingPickAllExcept => '选择不经过 VPN 的应用';

  @override
  String get appRoutingPickOnly => '选择使用 VPN 的应用';

  @override
  String appRoutingThroughVpn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 个应用经过 VPN',
      one: '$countString 个应用经过 VPN',
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
      other: '$countString 个应用直连',
      one: '$countString 个应用直连',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingTagVpn => 'VPN';

  @override
  String get appRoutingTagDirect => '直连';

  @override
  String get dnsServerTitle => 'DNS 服务器';

  @override
  String dnsServerCurrent(String dns) {
    return '当前: $dns';
  }

  @override
  String get proxyOnlyTitle => '仅代理模式';

  @override
  String proxyOnlyEnabled(int port) {
    return '使用 SOCKS 代理，端口 $port';
  }

  @override
  String get proxyOnlyDisabled => '使用代理模式代替 VPN';

  @override
  String get connectionModeTunnel => '隧道';

  @override
  String get connectionModeTunnelHint =>
      '所有应用都通过 Begzar。每次连接时 Windows 都会请求管理员权限。';

  @override
  String get connectionModeSystemProxy => '系统代理';

  @override
  String connectionModeSystemProxyHint(int port) {
    return '遵循 Windows 代理设置的应用使用 127.0.0.1:$port';
  }

  @override
  String get connectionModeProxyOnly => '仅代理';

  @override
  String connectionModeProxyOnlyHint(int port) {
    return '请自行将应用指向 SOCKS 端口 $port';
  }

  @override
  String get bypassLanTitle => 'Bypass LAN';

  @override
  String get bypassLanEnabled => 'SOCKS 监听所有接口 (0.0.0.0)';

  @override
  String get bypassLanDisabled => '允许局域网其他设备使用此代理';

  @override
  String get bypassLanRequiresProxy => '请先开启仅代理模式以使用 Bypass LAN';

  @override
  String get bypassLanRequiresProxyMode => '请选择仅代理以使用 Bypass LAN';

  @override
  String get bypassLanAddressesTitle => '设备地址';

  @override
  String get bypassLanNoAddresses => '未找到局域网地址';

  @override
  String bypassLanEndpoint(String ip, int port) {
    return 'socks5://$ip:$port';
  }

  @override
  String get routingRulesTitle => '网站和 IP 规则';

  @override
  String get routingRulesSubtitle => '为网站和 IP 设置路由或阻断';

  @override
  String routingRulesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 条自定义规则',
      one: '$countString 条自定义规则',
    );
    return '$_temp0';
  }

  @override
  String get routingRulesScreenTitle => '网站和 IP 规则';

  @override
  String get routingRulesHint => '自定义规则将在下次连接时生效。请重新连接 VPN 以应用更改。';

  @override
  String get routingTabDirect => '直连';

  @override
  String get routingTabBlock => '阻断';

  @override
  String get routingTabProxy => '代理';

  @override
  String get routingAddRule => '添加规则';

  @override
  String get routingEntryDomain => '域名';

  @override
  String get routingEntryIp => 'IP';

  @override
  String get routingDomainHint => 'example.com';

  @override
  String get routingIpHint => '10.0.0.0/8 或 8.8.8.8';

  @override
  String get routingInvalidInput => '域名或 IP 无效';

  @override
  String get routingEmptyDirect => '暂无直连规则';

  @override
  String get routingAlreadyListed => '该规则已在列表中';

  @override
  String get routingEmptyBlock => '暂无阻断规则';

  @override
  String get routingEmptyProxy => '暂无代理规则';

  @override
  String get settingsInfoReconnect => '更改将在重新连接 VPN 后生效';

  @override
  String get dnsDialogTitle => 'DNS 服务器';

  @override
  String get dnsDialogPrompt => '输入 DNS 服务器 IP 地址:';

  @override
  String get dnsDialogCommon => '常用 DNS 服务器:';

  @override
  String get dnsDialogInvalid => '请输入 IP 地址，例如 8.8.8.8';

  @override
  String get languageDialogTitle => '选择语言';

  @override
  String get languageChoiceHint => '之后可在设置中更改';

  @override
  String get languageContinue => '继续';

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
  String get clearAll => '全部清除';

  @override
  String get searchAppsHint => '搜索应用...';

  @override
  String get noAppsFound => '未找到应用';

  @override
  String get noSearchResults => '无结果';

  @override
  String get premiumHeroTitle => 'Begzar 高级版';

  @override
  String get premiumHeroSubtitle => '登录以访问高级服务器并管理订阅';

  @override
  String get signInToPremium => '登录高级版';

  @override
  String get usePremiumCredentials => '使用您的高级版账户凭据';

  @override
  String get password => '密码';

  @override
  String get signIn => '登录';

  @override
  String get signingIn => '登录中...';

  @override
  String get emailOrUsername => '邮箱或用户名';

  @override
  String get createAccountLink => '还没有账户？立即创建';

  @override
  String get signInLink => '已有账户？登录';

  @override
  String get createAccountTitle => '创建账户';

  @override
  String get createAccountHint => '我们会向您的邮箱发送验证码';

  @override
  String get email => '邮箱';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get createAccount => '创建账户';

  @override
  String get creatingAccount => '正在创建...';

  @override
  String get signUpPrivacyNotice => '创建账户即表示您接受隐私政策';

  @override
  String get verifyEmailTitle => '查看您的邮箱';

  @override
  String get verifyEmailHint => '请输入我们发送到以下邮箱的 6 位验证码：';

  @override
  String get confirmationCode => '验证码';

  @override
  String get confirmCode => '确认';

  @override
  String get confirmingCode => '正在确认...';

  @override
  String get resendCode => '重新发送';

  @override
  String resendCodeIn(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$secondsString 秒后可重新发送',
      one: '1 秒后可重新发送',
    );
    return '$_temp0';
  }

  @override
  String get changeEmail => '更改邮箱';

  @override
  String get errEmailFormat => '请输入有效的邮箱地址';

  @override
  String errPasswordLength(int min) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);

    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: '至少 $minString 个字符',
      one: '至少 1 个字符',
    );
    return '$_temp0';
  }

  @override
  String get errPasswordMismatch => '两次输入的密码不一致';

  @override
  String get errCodeFormat => '请输入 6 位验证码';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountTitle => '删除您的账户？';

  @override
  String get deleteAccountMessage => '这将立即删除您的账户、已绑定的设备以及剩余的付费时长，且无法撤销。';

  @override
  String get deleteAccountPlayNote => '删除账户不会取消 Google Play 订阅。';

  @override
  String get manageGooglePlaySubscription => '在 Google Play 中管理';

  @override
  String get deleteAccountConfirm => '删除';

  @override
  String get deletingAccount => '正在删除...';

  @override
  String get accountDeleted => '您的账户已删除';

  @override
  String paywallDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 台设备',
      one: '1 台设备',
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
      other: '$countString 个月',
      one: '1 个月',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitle => '升级到高级版';

  @override
  String get paywallCompareHeading => '您将获得';

  @override
  String get paywallRowAds => '广告';

  @override
  String get paywallBasicAds => '每次都有';

  @override
  String get paywallPremiumAds => '无';

  @override
  String get paywallRowCountry => '国家/地区';

  @override
  String get paywallBasicCountry => '自动';

  @override
  String get paywallIncluded => '包含';

  @override
  String get paywallRowServers => '服务器';

  @override
  String get paywallBasicServers => '共享';

  @override
  String get paywallPremiumServers => '全速';

  @override
  String get paywallRowDevices => '设备';

  @override
  String get paywallNotIncluded => '不包含';

  @override
  String paywallPremiumDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多 $countString 台',
      one: '1 台',
    );
    return '$_temp0';
  }

  @override
  String get paywallDevicesHint => '可同时登录';

  @override
  String get paywallFewerDevices => '减少设备';

  @override
  String get paywallMoreDevices => '增加设备';

  @override
  String paywallPerMonth(String price) {
    return '$price/月';
  }

  @override
  String paywallSave(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '省 $percentString%';
  }

  @override
  String get paywallBestValue => '最划算';

  @override
  String paywallContinue(String period, String price, int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.selectLogic(period, {
      'month': '继续 — $price/月',
      'year': '继续 — $price/年',
      'other': '继续 — $monthsString 个月 $price',
    });
    return '$_temp0';
  }

  @override
  String get subscriptionAutoRenews => '订阅将自动续订，可随时在 Google Play 中取消。';

  @override
  String get paymentProblemsLink => '付款遇到问题？';

  @override
  String get purchasePending => '您的付款正在处理中，Google Play 确认后即可开通高级版。';

  @override
  String get purchaseConfirmLater => '付款已完成，我们确认后即会开通高级版。';

  @override
  String get purchaseGranted => '高级版已开通';

  @override
  String get signInToSubscribe => '请登录或创建账户后订阅';

  @override
  String get premiumActive => '高级版已激活';

  @override
  String get premiumAccountInactive => '账户未激活';

  @override
  String get premiumNoSubscription => '尚未订阅';

  @override
  String get premiumNoSubscriptionHint => '高级版提供更快且无广告的服务器。购买后请点按“刷新”。';

  @override
  String get premiumNoSubscriptionHintDesktop => '高级版提供更快且无广告的服务器。购买后请点击“刷新”。';

  @override
  String get premiumExpiredHint => '您的订阅已到期。续订后即可再次使用高级服务器。';

  @override
  String get premiumInactiveHint => '此账户已被停用。请联系客服恢复。';

  @override
  String get premiumPerkServers => '高级服务器';

  @override
  String get planFree => '免费';

  @override
  String get premiumPerkStaticIp => '固定 IP';

  @override
  String get premiumPerkNoAds => '无广告';

  @override
  String get homeFactMode => '模式';

  @override
  String get homeFactDns => 'DNS';

  @override
  String get homeFactApps => '应用';

  @override
  String get homeModeVpn => 'VPN';

  @override
  String get homeSupport => '客服';

  @override
  String get navSettings => '设置';

  @override
  String get navHome => '首页';

  @override
  String get navPremium => '高级版';

  @override
  String get homeAppsAll => '所有应用';

  @override
  String homeAppsExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '除 $countString 个外全部';
  }

  @override
  String homeAppsOnly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '仅 $countString 个';
  }

  @override
  String get expires => '到期';

  @override
  String get remaining => '剩余';

  @override
  String get accountStatus => '账户状态';

  @override
  String get userStatusActive => '活跃';

  @override
  String get userStatusExpired => '已过期';

  @override
  String get userStatusInactive => '未激活';

  @override
  String get userStatusDisabled => '已禁用';

  @override
  String get userStatusSuspended => '已暂停';

  @override
  String get userStatusBanned => '已封禁';

  @override
  String get expired => '已过期';

  @override
  String get refresh => '刷新';

  @override
  String get signOut => '退出';

  @override
  String get signingOut => '退出中...';

  @override
  String get deviceBindingInfo => '您的账户已绑定此设备。高级版配置受设备锁定保护。';

  @override
  String get linkedDevices => '已关联设备';

  @override
  String get linkedDevicesHint => '正在加载设备...';

  @override
  String devicesCount(int active, int max) {
    final intl.NumberFormat activeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String activeString = activeNumberFormat.format(active);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$activeString/$maxString 台设备';
  }

  @override
  String get noLinkedDevices => '未找到关联设备';

  @override
  String get thisDevice => '本设备';

  @override
  String deviceLoggedInAt(String date) {
    return '登录于 $date';
  }

  @override
  String get removeDevice => '移除';

  @override
  String get removeDeviceTitle => '移除设备';

  @override
  String removeDeviceMessage(String name) {
    return '从高级版账户移除「$name」？该设备将立即退出登录。';
  }

  @override
  String get deviceRemovedSuccess => '设备已成功移除';

  @override
  String get tryAgain => '重试';

  @override
  String get disconnect => '断开连接';

  @override
  String get tunnelStalledTitle => '流量无法通过';

  @override
  String get tunnelStalledHint => '此服务器已停止响应';

  @override
  String get tunnelStalledSwitch => '切换服务器';

  @override
  String get notifTunnelTitle => 'Begzar 已连接';

  @override
  String get notifTunnelVpnMode => 'VPN 模式';

  @override
  String get notifTunnelProxyMode => '代理模式';

  @override
  String get notifTunnelChannelName => '连接';

  @override
  String get notifTunnelChannelDescription => '在隧道连接期间显示';

  @override
  String get premiumServersTitle => '高级服务器';

  @override
  String get premiumServersSubtitle => '选择要连接的服务器';

  @override
  String get premiumServersConnectedHint => '点按已连接的服务器即可断开';

  @override
  String get premiumServersConnectedHintDesktop => '点击已连接的服务器即可断开';

  @override
  String get lastConnected => '上次连接';

  @override
  String get configConnected => '已连接';

  @override
  String get premiumServersEmpty => '暂无可用的高级服务器';

  @override
  String premiumServerConfigsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 个配置';
  }

  @override
  String get serverRowChoose => '选择服务器';

  @override
  String get serverRowChooseHint => '点按查看可用的服务器';

  @override
  String get serverRowChooseHintDesktop => '点击查看可用的服务器';

  @override
  String get serverRowWithdrawn => '已移除 · 请选择其他服务器';

  @override
  String get serverRowPremium => '高级服务器';

  @override
  String get serverRowPremiumHint => '自选节点，免除广告';

  @override
  String get serverRowExpired => '订阅已到期';

  @override
  String get serverRowExpiredHint => '续订后即可重新选择服务器';

  @override
  String get serverRowInactive => '账号已停用';

  @override
  String get serverRowInactiveHint => '请联系客服恢复使用';

  @override
  String get notificationPermissionTitle => '需要通知权限';

  @override
  String get notificationPermissionMessage =>
      '必须开启通知才能使用 Begzar，以便接收重要更新和服务消息。';

  @override
  String get enableNotifications => '开启通知';

  @override
  String get openNotificationSettings => '打开设置';

  @override
  String get notificationPermissionSettingsHint => '通知已关闭。请在设备设置中开启通知以继续使用。';

  @override
  String get macOsPermissionsTitle => '需要权限';

  @override
  String get macOsPermissionsMessage =>
      '在 macOS 上，Begzar 需要安全存储和系统代理权限。请全部授权后继续。';

  @override
  String get macOsPermissionSecureStorage => '安全存储';

  @override
  String get macOsPermissionSecureStorageHint => '安全保存设备密钥和账户数据。';

  @override
  String get macOsPermissionSystemProxy => '系统代理';

  @override
  String get macOsPermissionSystemProxyHint => '将浏览器和应用流量通过 Begzar 路由。';

  @override
  String get macOsPermissionGrant => '授权';

  @override
  String get macOsPermissionGrantAll => '授权全部权限';

  @override
  String get macOsPermissionContinue => '继续';

  @override
  String get macOsPermissionsBlockedHint => '在获得全部权限之前无法使用应用。';

  @override
  String get updateRequired => '需要更新';

  @override
  String get updateDescription => '有新版本可用。请更新以继续使用应用。';

  @override
  String get currentVersion => '当前版本';

  @override
  String get requiredVersion => '所需版本';

  @override
  String get updateNow => '立即更新';

  @override
  String get updateOpenFailed => '无法打开更新页面。请手动前往应用商店。';

  @override
  String updateError(String e) {
    return '打开更新页面出错: $e';
  }

  @override
  String get updateAvailableTitle => '有新版本可用';

  @override
  String updateAvailableVersions(String latest, String installed) {
    return '新版本 $latest · 当前 $installed';
  }

  @override
  String get adBadge => '广告';

  @override
  String adCloseCountdown(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString 秒后可关闭';
  }

  @override
  String adCloseSeconds(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString';
  }

  @override
  String get adSkipWarningTitle => '连接已断开';

  @override
  String get adSkipWarningMessage => '由于您未看完广告，连接已断开。购买高级版可移除广告。';

  @override
  String get close => '关闭';

  @override
  String get linkOpenFailed => '无法打开链接';

  @override
  String get errSubscriptionRequired => '请先使用有效的高级版订阅登录';

  @override
  String get errCredentialsRequired => '用户名和密码为必填项';

  @override
  String loginFailed(String e) {
    return '登录失败: $e';
  }

  @override
  String get errRefreshFailed => '刷新订阅失败';

  @override
  String get errSignOutFailed => '退出失败，请重试。';

  @override
  String get errLoginFailed => '登录失败';

  @override
  String get errLoadSubscription => '加载订阅失败';

  @override
  String get errLogoutFailed => '退出失败';

  @override
  String get errSessionNotFound => '未找到高级版会话，请重新登录。';

  @override
  String get errUnexpectedConfigs => '高级版配置响应异常';

  @override
  String get errConfigsRequestFailed => '高级版配置请求失败';

  @override
  String get errNoConfigsFound => '未找到高级版配置（解密或解析失败）';

  @override
  String loadConfigsFailed(String e) {
    return '加载高级版配置失败: $e';
  }

  @override
  String loadDevicesFailed(String e) {
    return '加载设备失败: $e';
  }

  @override
  String loadPremiumServersFailed(String e) {
    return '加载高级服务器失败: $e';
  }

  @override
  String removeDeviceFailed(String e) {
    return '移除设备失败: $e';
  }

  @override
  String get errLoadDevices => '加载设备失败';

  @override
  String get errLoadPremiumServers => '加载高级服务器失败';

  @override
  String get errRemoveDevice => '移除设备失败';

  @override
  String get errDeviceNotFound => '未找到设备';

  @override
  String get errInvalidCredentials => '用户名或密码无效';

  @override
  String get errDeviceBound => '此账户已绑定其他设备';

  @override
  String get errTooManyAttempts => '尝试次数过多，请稍后再试';

  @override
  String get errEmailTaken => '该邮箱已注册账户';

  @override
  String get errWrongPassword => '密码不正确';

  @override
  String get errPasswordRequired => '请输入密码';

  @override
  String get errCodeInvalid => '验证码不正确';

  @override
  String get errCodeExpired => '验证码已过期，请重新发送';

  @override
  String get errSignUpFailed => '无法创建账户';

  @override
  String get errVerifyFailed => '无法验证验证码';

  @override
  String get errDeleteAccountFailed => '无法删除账户';

  @override
  String get errPlansUnavailable => '无法加载套餐，请稍后再试';

  @override
  String get errPurchaseFailed => '购买未完成';

  @override
  String get errPlayAlreadyOwned => '此 Google 账户已为一个 Begzar 订阅付费，请登录购买该订阅的账户';

  @override
  String get errRateLimit => '请求过于频繁';

  @override
  String get errAccessDenied => '服务器拒绝访问';

  @override
  String get errNoResponse => '服务器无响应';

  @override
  String get errNoStorageAccess => '无法访问存储';

  @override
  String get errEngineLogUnavailable => '无法读取引擎日志';

  @override
  String get errEngineMissing => '此版本不包含 Begzar 引擎，无法连接';

  @override
  String get engineLogTitle => '引擎日志';

  @override
  String get engineLogAll => '全部';

  @override
  String get engineLogEngine => '引擎';

  @override
  String get engineLogClear => '清除';

  @override
  String get engineLogExport => '导出';

  @override
  String get engineLogEmpty => '暂无日志';

  @override
  String get engineLogDropped => '较早的日志已被丢弃';

  @override
  String get engineLogSaved => '日志已保存';

  @override
  String get engineLogClose => '关闭';

  @override
  String get errConnectionTimeout => '连接超时';

  @override
  String get errNetworkError => '网络错误';

  @override
  String get errNoConfigsFromServer => '服务器未返回可用配置';

  @override
  String get errNoConfigsAvailable => '没有可用配置';

  @override
  String get errNoWorkingConfig => '未找到可用配置';

  @override
  String get errApiV2Unavailable => '连接服务不可用';

  @override
  String get errPremiumApiUnavailable => '高级服务不可用';

  @override
  String get errProxyTestFailed => '服务器连通性测试失败';

  @override
  String get errInvalidConfig => '代理配置无效';

  @override
  String get errDisconnectFailed => '断开连接失败';

  @override
  String get errConnectionFailed => '连接失败';

  @override
  String get errElevationDeclined =>
      '隧道模式需要管理员权限。请在 Windows 询问时允许，或在设置中选择系统代理。';

  @override
  String get errTunnelUnavailable => '隧道模式无法启动。请重试，或在设置中选择系统代理。';

  @override
  String get errTunnelStopped => '隧道已停止。请重新连接。';

  @override
  String get errUnauthorized => '未授权的请求';

  @override
  String get errForbidden => '访问被拒绝';

  @override
  String get errDeviceInitFailed => '设备初始化失败';

  @override
  String get errFetchConfigsFailed => '从服务器获取配置失败';

  @override
  String get errSecureConnectionFailed => '与服务器的安全连接失败';

  @override
  String get errClockSkew => '此设备的日期或时间不正确';

  @override
  String get errClockSkewHint => '请开启自动日期、时间和时区，然后重试';

  @override
  String get errRequestUnverified => '无法验证此请求';

  @override
  String get errRequestUnverifiedHint => '请完全关闭应用后重新打开';

  @override
  String get errReplayDetected => '该请求已被使用';

  @override
  String get errReplayDetectedHint => '请稍候再试';

  @override
  String get errIpBlocked => '此网络无法创建新会话';

  @override
  String get errIpBlockedHint => '请换一个网络，或等到明天再试';

  @override
  String get errMissingSession => '此设备在服务器上没有会话';

  @override
  String get errMissingSessionHint => '请再次连接。如果仍然失败，请完全关闭应用后重试';

  @override
  String get errDeviceInitFailedHint => '请检查网络后重试';

  @override
  String get errInvalidCredentialsHint => '如果忘记密码，请在 Premium 机器人中修改';

  @override
  String get errDeviceLimit => '此账户没有空余的设备名额';

  @override
  String get errDeviceLimitHint => '请在 Premium 机器人中重置已注册设备，然后重新登录';

  @override
  String get errDeviceNotRegistered => '此设备未登记在该账户下';

  @override
  String get errDeviceNotRegisteredHint => '请退出并重新登录以注册此设备';

  @override
  String get errAccountDisabled => '您的账户已被停用';

  @override
  String get errAccountDisabledHint => '请联系 Premium 机器人获取帮助';

  @override
  String get errAccountExpired => '您的高级订阅已过期';

  @override
  String get errAccountExpiredHint => '请在 Premium 机器人中续订';

  @override
  String get errRateLimitHint => '请等待一分钟后重试';

  @override
  String errRateLimitWait(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '请在 $nString 秒后重试';
  }

  @override
  String get errSessionCredentials => '请重新登录以继续';

  @override
  String get errSessionCredentialsHint => '如果无法登录，请在 Premium 机器人中修改密码';

  @override
  String get getHelp => '获取帮助';

  @override
  String daysLeft(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString 天',
      one: '$daysString 天',
    );
    return '$_temp0';
  }
}
