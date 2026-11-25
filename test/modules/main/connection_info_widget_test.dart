import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/domain/tunnel_liveness.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/tunnel_liveness_notifier.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:begzar/modules/ip_info/presentation/controllers/ip_info_provider.dart';
import 'package:begzar/modules/main/presentation/controllers/ping_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_info_widget.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';

/// Reports a fixed status without watching the service graph.
///
/// `ConnectionNotifier.build` only reads three providers and returns a fresh
/// entity, so replacing it costs nothing and keeps the real services out of a
/// widget test.
class _FixedConnection extends ConnectionNotifier {
  _FixedConnection(this.status);

  final ConnectionStatus status;

  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: status);
}

/// Reports a fixed latency, so the pill can be drawn in the state that shows
/// a reading without a tunnel to measure through.
class _FixedPing extends PingNotifier {
  _FixedPing(this.reading);

  final AsyncValue<int?> reading;

  @override
  AsyncValue<int?> build() => reading;
}

class _FixedPremium extends PremiumNotifier {
  _FixedPremium(this.value);

  final PremiumState value;

  @override
  PremiumState build() => value;
}

class _FixedServers extends PremiumServersNotifier {
  _FixedServers(this.value);

  final PremiumServersState value;

  @override
  PremiumServersState build() => value;
}

/// Reports what the traffic checks found, without running any.
class _FixedLiveness extends TunnelLivenessNotifier {
  _FixedLiveness(this.value);

  final TunnelLiveness value;

  @override
  TunnelLiveness build() => value;
}

/// What the checks say about a tunnel that stopped carrying traffic.
const _deadTunnel = TunnelLiveness(
  failuresInARow: TunnelLiveness.deadAfterFailures,
);

const _designSize = Size(390, 844);

Widget _pillUnderTest(
  Either<IpInfoFailure, IpInfo>? reading, {
  Locale locale = const Locale('en'),
  AsyncValue<int?> ping = const AsyncValue.data(null),
  (PremiumState, PremiumServersState)? premium,
  TunnelLiveness liveness = const TunnelLiveness(),
}) {
  return ProviderScope(
    overrides: [
      connectionProvider.overrideWith(
        () => _FixedConnection(ConnectionStatus.connected),
      ),
      ipInfoProvider.overrideWith((ref) async => reading),
      pingProvider.overrideWith(() => _FixedPing(ping)),
      tunnelLivenessProvider.overrideWith(() => _FixedLiveness(liveness)),
      if (premium != null) ...[
        premiumProvider.overrideWith(() => _FixedPremium(premium.$1)),
        premiumServersProvider.overrideWith(() => _FixedServers(premium.$2)),
      ],
    ],
    child: ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        locale: locale,
        // Same four the app declares in app.dart. Dropping the Cupertino one
        // passes for English and throws the moment a test asks for fa.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fa')],
        home: const Scaffold(body: Center(child: ConnectionInfoWidget())),
      ),
    ),
  );
}

/// Draws at the size the pill is designed for.
///
/// The harness defaults to 800x600, which is wider than it is tall — and
/// ScreenUtil takes `.w` from the width ratio and `.h` from the height one, so
/// against that surface the pill's reserved box is squashed to two thirds of
/// its height while the text inside it doubles. No handset is that shape.
void _drawOnAHandset(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _designSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  const anExit = IpInfo(
    ip: '203.0.113.7',
    country: 'Sweden',
    countryCode: 'SE',
  );

  testWidgets('an exit address is shown, masked', (tester) async {
    _drawOnAHandset(tester);
    await tester.pumpWidget(_pillUnderTest(right(anExit)));
    await tester.pumpAndSettle();

    expect(find.text('203.0.***.***'), findsOneWidget);
    expect(find.text('Sweden'), findsOneWidget);
    expect(
      find.text('203.0.113.7'),
      findsNothing,
      reason: 'the pill is on a screen someone may be showing to somebody else',
    );
  });

  testWidgets('the address reads left to right in Persian too', (tester) async {
    _drawOnAHandset(tester);
    await tester.pumpWidget(
      _pillUnderTest(right(anExit), locale: const Locale('fa')),
    );
    await tester.pumpAndSettle();

    final address = tester.widget<Text>(find.text('203.0.***.***'));
    expect(
      address.textDirection,
      TextDirection.ltr,
      reason:
          'the dots and asterisks are bidi-neutral, so an RTL paragraph '
          'reorders the runs around them and shows a different address',
    );
  });

  testWidgets('no reading yet reads as loading', (tester) async {
    _drawOnAHandset(tester);
    await tester.pumpWidget(_pillUnderTest(null));
    // Not pumpAndSettle: the shimmer repeats forever by design, so there is no
    // steady state to settle into. Pumping past the pill's enter animation is
    // enough to see what it landed on.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byType(Shimmer),
      findsOneWidget,
      reason: 'null means the tunnel is still coming up, not that it failed',
    );
  });

  testWidgets('every source refusing says so instead of loading forever', (
    tester,
  ) async {
    _drawOnAHandset(tester);
    await tester.pumpWidget(
      _pillUnderTest(left(const NoSourceAnsweredFailure())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Location unavailable'),
      findsOneWidget,
      reason:
          'this state was unreachable while a failed lookup arrived as '
          'null: the pill shimmered forever and the translated string could '
          'never appear on screen',
    );
    expect(find.byType(Shimmer), findsNothing);
  });

  group('a tunnel that stopped carrying traffic', () {
    testWidgets('should say so and offer a switch or a disconnect', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(right(anExit), liveness: _deadTunnel),
      );
      await tester.pumpAndSettle();

      expect(find.text('No traffic getting through'), findsOneWidget);
      expect(find.text('Switch server'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(
        find.text('203.0.***.***'),
        findsNothing,
        reason: 'the exit it names is not where anything is going',
      );
    });

    testWidgets('should fit the card in Persian', (tester) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(
          right(anExit),
          liveness: _deadTunnel,
          locale: const Locale('fa'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('should show the exit as before while traffic flows', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(_pillUnderTest(right(anExit)));
      await tester.pumpAndSettle();

      expect(find.text('203.0.***.***'), findsOneWidget);
      expect(find.text('Switch server'), findsNothing);
    });
  });

  group('the flag', () {
    // The lookup once put a Swedish exit in Brazil, and the card said Brazil
    // under a server row that said Sweden. The server is the one the user
    // picked, so where the row names one, the card shows its flag.
    testWidgets('should be the flag of the server the row names', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      const brazil = IpInfo(
        ip: '203.0.113.7',
        country: 'Brazil',
        countryCode: 'BR',
      );
      await tester.pumpWidget(
        _pillUnderTest(
          right(brazil),
          premium: (
            PremiumSignedIn(
              account: PremiumAccount(
                username: 'someone',
                expireDate: DateTime.now()
                    .add(const Duration(days: 30))
                    .toIso8601String(),
              ),
            ),
            const PremiumServersState(
              servers: [
                PremiumServer(
                  id: 7,
                  name: 'Sweden',
                  configs: [
                    PremiumServerConfig(
                      id: 41,
                      name: 'SE-01',
                      url: 'vless://one',
                    ),
                  ],
                ),
              ],
              activeConfigId: 41,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final flag = tester.widget<PremiumServerIcon>(
        find.byType(PremiumServerIcon),
      );
      expect(flag.flagCode, 'se');
      expect(find.text(brazil.flagEmoji), findsNothing);
    });

    // The free tier, or a server list that never loaded: no server is named,
    // and the lookup is the only answer there is.
    testWidgets('should be the lookup\'s flag when no server is named', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(_pillUnderTest(right(anExit)));
      await tester.pumpAndSettle();

      expect(find.text(anExit.flagEmoji), findsOneWidget);
      expect(find.byType(PremiumServerIcon), findsNothing);
    });
  });

  group('the two marks down the trailing edge', () {
    // The tick is a glyph on a filled disc and the refresh is a bare glyph, so
    // making them the same *icon* size leaves the discs off centre from each
    // other: they sit one above the other with nothing else in that column,
    // which is exactly where a few points of drift is visible.
    testWidgets('should hang the refresh on the tick\'s centre line', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(right(anExit), ping: const AsyncValue.data(185)),
      );
      await tester.pumpAndSettle();

      final tick = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Iconsax.tick_circle_copy),
              matching: find.byType(Container),
            )
            .first,
      );
      final refresh = tester.getRect(find.byIcon(Iconsax.refresh_copy));

      expect(
        refresh.center.dx,
        closeTo(tick.center.dx, 0.5),
        reason:
            'the disc above and the glyph below are the only two things in '
            'that column, so the eye lines them up by their centres',
      );
    });
  });

  group('the panel\'s leading column', () {
    // The flag tile is 32pt and the speed glyph 14pt. Left to size themselves
    // and each flush to the content edge, they hung off two different
    // gutters: the glyph sat 9pt inside the tile's centre and the reading
    // started 22pt inside the address above it.
    testWidgets('should stand every leading mark in one column', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(right(anExit), ping: const AsyncValue.data(185)),
      );
      await tester.pumpAndSettle();

      final flag = tester.getRect(find.text(anExit.flagEmoji));
      final glyph = tester.getRect(find.byIcon(Iconsax.speedometer_copy));

      expect(glyph.center.dx, closeTo(flag.center.dx, 0.5));
    });

    testWidgets('should start the reading under the address', (tester) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(right(anExit), ping: const AsyncValue.data(185)),
      );
      await tester.pumpAndSettle();

      final address = tester.getRect(find.text(anExit.maskedIp));
      final reading = tester.getRect(find.textContaining('\u00b7'));

      expect(reading.left, closeTo(address.left, 0.5));
    });
  });

  group('the reading beside the speed glyph', () {
    // Every Iconsax glyph is centred in its own box — the font file gives
    // the offset as 0.0000em — so the glyph is never the crooked half. Text
    // is: a Row centres the em box a face declares, and the letters sit
    // wherever that face's ascent and descent leave them. Correcting the
    // text keeps glyphs where they belong, which matters most for the ones
    // drawn inside a shape.
    testWidgets('should drop onto the glyph\'s centre line', (tester) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(right(anExit), ping: const AsyncValue.data(185)),
      );
      await tester.pumpAndSettle();

      // The separator is punctuation in every locale's reading, which is the
      // one part of the string a test can name without asserting on a
      // translation.
      final reading = find.textContaining('\u00b7');
      final rowCentreY = tester
          .getRect(find.ancestor(of: reading, matching: find.byType(Row)).first)
          .center
          .dy;

      // The drop belongs to the face the reading is set in: the mono face
      // where the language has one, and otherwise the inherited one.
      final context = tester.element(reading);
      final family =
          monoFamilyOf(context) ??
          DefaultTextStyle.of(context).style.fontFamily;

      expect(
        tester.getRect(reading).center.dy - rowCentreY,
        closeTo(
          AppLayout.mainPingValueSize.sp * opticalTextDropFor(family),
          0.01,
        ),
        reason:
            'a row centres the font\'s box, and the letters are not centred '
            'in it — the reading has to come down to meet the glyph',
      );
    });

    testWidgets('should leave the connected tick centred in its disc', (
      tester,
    ) async {
      _drawOnAHandset(tester);
      await tester.pumpWidget(
        _pillUnderTest(right(anExit), ping: const AsyncValue.data(185)),
      );
      await tester.pumpAndSettle();

      final glyph = find.byIcon(Iconsax.tick_circle_copy);
      final disc = tester.getRect(
        find.ancestor(of: glyph, matching: find.byType(Container)).first,
      );

      expect(
        tester.getCenter(glyph).dy,
        closeTo(disc.center.dy, 0.01),
        reason:
            'a glyph inside a shape has nothing to be crooked against, so '
            'nudging it only takes it off the centre of its own disc',
      );
    });
  });
}
