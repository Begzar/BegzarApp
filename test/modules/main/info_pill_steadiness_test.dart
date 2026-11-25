import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:begzar/modules/ip_info/presentation/controllers/ip_info_provider.dart';
import 'package:begzar/modules/main/presentation/controllers/ping_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_info_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

const _locales = [Locale('en'), Locale('fa'), Locale('ru'), Locale('zh')];

const _designSize = Size(393, 852);
const _largeHandset = Size(412, 915);
const _smallHandset = Size(360, 780);

void _drawOn(WidgetTester tester, Size surface) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _FixedConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: ConnectionStatus.connected);
}

class _FixedPing extends PingNotifier {
  _FixedPing(this.reading);

  final AsyncValue<int?> reading;

  @override
  AsyncValue<int?> build() => reading;

  @override
  Future<void> measure() async {}
}

Widget _panelIn(
  Locale locale, {
  required AsyncValue<int?> ping,
  required Either<IpInfoFailure, IpInfo>? exit,
}) {
  return ProviderScope(
    overrides: [
      connectionProvider.overrideWith(_FixedConnection.new),
      pingProvider.overrideWith(() => _FixedPing(ping)),
      ipInfoProvider.overrideWith((ref) async => exit),
    ],
    child: ScreenUtilInit(
      designSize: _designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: _locales,
        home: const Scaffold(body: Center(child: ConnectionInfoWidget())),
      ),
    ),
  );
}

Rect _boxOf(WidgetTester tester) {
  return tester.getRect(
    find.descendant(
      of: find.byType(ConnectionInfoWidget),
      matching: find.byType(AnimatedSwitcher),
    ),
  );
}

Future<void> _pumpPastEntry(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

const _anExit = IpInfo(ip: '203.0.113.7', country: 'Sweden', countryCode: 'SE');

const _aLongExit = IpInfo(
  ip: '203.255.113.7',
  country: 'Bosnia and Herzegovina',
  countryCode: 'BA',
);

const _anIpv6Exit = IpInfo(
  ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
  country: 'Sweden',
  countryCode: 'SE',
);

const _extremes = <String, (AsyncValue<int?>, IpInfo)>{
  'the longest country there is': (
    AsyncValue.data(120),
    IpInfo(
      ip: '255.255.255.255',
      country: 'United States Minor Outlying Islands',
      countryCode: 'UM',
    ),
  ),
  'a provider that named nothing': (
    AsyncValue.data(120),
    IpInfo(ip: 'Unknown', country: 'Unknown', countryCode: 'US'),
  ),
  'an address that would not parse': (
    AsyncValue.data(120),
    IpInfo(
      ip: 'not-an-address-at-all.example.invalid',
      country: 'Sweden',
      countryCode: 'SE',
    ),
  ),
  'a latency that ran to five digits': (
    AsyncValue.data(99999),
    IpInfo(ip: '203.0.113.7', country: 'Sweden', countryCode: 'SE'),
  ),
  'a latency that came back negative': (
    AsyncValue.data(-1),
    IpInfo(ip: '203.0.113.7', country: 'Sweden', countryCode: 'SE'),
  ),
};

Future<Set<Rect>> _boxesAcrossStates(WidgetTester tester, Locale locale) async {
  final exits = <Rect>{};

  Future<void> record({
    required AsyncValue<int?> ping,
    required Either<IpInfoFailure, IpInfo>? exit,
  }) async {
    await tester.pumpWidget(_panelIn(locale, ping: ping, exit: exit));
    await _pumpPastEntry(tester);
    exits.add(_boxOf(tester));
  }

  await record(ping: const AsyncValue.data(null), exit: null);
  await record(ping: const AsyncValue<int?>.loading(), exit: null);
  await record(ping: const AsyncValue.data(120), exit: right(_anExit));
  await record(ping: const AsyncValue.data(8), exit: right(_aLongExit));
  await record(ping: const AsyncValue.data(1200), exit: right(_anIpv6Exit));
  await record(
    ping: AsyncValue<int?>.error('ping-failed', StackTrace.empty),
    exit: left(const NoSourceAnsweredFailure()),
  );

  return exits;
}

void main() {
  group('a reading stays where it was drawn', () {
    for (final surface in [_designSize, _largeHandset]) {
      for (final locale in _locales) {
        testWidgets('${locale.languageCode} at ${surface.width.toInt()}pt', (
          tester,
        ) async {
          _drawOn(tester, surface);
          final exits = await _boxesAcrossStates(tester, locale);

          expect(
            exits,
            hasLength(1),
            reason: 'the exit panel moved or resized between states: $exits',
          );
        });
      }
    }
  });

  group('the reserved box survives the ends of every input range', () {
    for (final surface in [_smallHandset, _designSize, _largeHandset]) {
      for (final entry in _extremes.entries) {
        testWidgets('${entry.key}, at ${surface.width.toInt()}pt', (
          tester,
        ) async {
          _drawOn(tester, surface);
          final (ping, exit) = entry.value;

          await tester.pumpWidget(
            _panelIn(const Locale('fa'), ping: ping, exit: right(exit)),
          );
          await _pumpPastEntry(tester);
          final underLoad = _boxOf(tester);

          await tester.pumpWidget(
            _panelIn(
              const Locale('fa'),
              ping: const AsyncValue.data(120),
              exit: right(_anExit),
            ),
          );
          await _pumpPastEntry(tester);

          expect(
            underLoad,
            _boxOf(tester),
            reason:
                'the box is reserved, so nothing a provider returns and no '
                'latency may change it — only what is drawn inside it',
          );
        });
      }
    }
  });

  testWidgets('a reading too long for its panel does not widen it', (
    tester,
  ) async {
    _drawOn(tester, _designSize);
    await tester.pumpWidget(
      _panelIn(
        const Locale('en'),
        ping: const AsyncValue.data(120),
        exit: right(_anIpv6Exit),
      ),
    );
    await _pumpPastEntry(tester);
    final overLong = _boxOf(tester);

    await tester.pumpWidget(
      _panelIn(
        const Locale('en'),
        ping: const AsyncValue.data(120),
        exit: right(_anExit),
      ),
    );
    await _pumpPastEntry(tester);

    expect(
      _boxOf(tester),
      overLong,
      reason:
          'a masked IPv6 address is the case a content-sized panel stretched '
          'furthest for. It ends in an ellipsis instead.',
    );
  });
}
