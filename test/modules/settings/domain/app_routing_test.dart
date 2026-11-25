import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutingMode', () {
    test('should read an unknown stored mode as all-except', () {
      expect(AppRoutingMode.fromStored('sideways'), AppRoutingMode.allExcept);
      expect(AppRoutingMode.fromStored(null), AppRoutingMode.allExcept);
    });

    test('should read each stored name back as its own mode', () {
      for (final mode in AppRoutingMode.values) {
        expect(AppRoutingMode.fromStored(mode.storedName), mode);
      }
    });

    test('should store the names all_except and only_selected', () {
      expect(AppRoutingMode.allExcept.storedName, 'all_except');
      expect(AppRoutingMode.onlySelected.storedName, 'only_selected');
    });
  });

  group('AppRouting', () {
    test('should send the apps only to the side its mode names', () {
      const onlySome = AppRouting(
        mode: AppRoutingMode.onlySelected,
        apps: ['a'],
      );
      const allExcept = AppRouting(mode: AppRoutingMode.allExcept, apps: ['a']);

      expect(onlySome.onlyThrough, ['a']);
      expect(onlySome.bypassing, isEmpty);
      expect(allExcept.bypassing, ['a']);
      expect(allExcept.onlyThrough, isEmpty);
    });

    test('should be all-except with no apps when it is none', () {
      expect(AppRouting.none.mode, AppRoutingMode.allExcept);
      expect(AppRouting.none.apps, isEmpty);
    });

    test('should compare equal when the mode and the apps match', () {
      const first = AppRouting(mode: AppRoutingMode.onlySelected, apps: ['a']);
      const second = AppRouting(mode: AppRoutingMode.onlySelected, apps: ['a']);
      const otherMode = AppRouting(mode: AppRoutingMode.allExcept, apps: ['a']);
      const otherApps = AppRouting(
        mode: AppRoutingMode.onlySelected,
        apps: ['b'],
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(otherMode));
      expect(first, isNot(otherApps));
    });
  });

  group('AppRoutingSelection', () {
    test('should start in all-except mode with both lists empty', () {
      expect(AppRoutingSelection.initial.mode, AppRoutingMode.allExcept);
      expect(AppRoutingSelection.initial.allExcept, isEmpty);
      expect(AppRoutingSelection.initial.onlySelected, isEmpty);
    });

    test("should keep each mode's list when the mode changes", () {
      const selection = AppRoutingSelection(
        allExcept: {'a'},
        onlySelected: {'b'},
      );

      final onlySome = selection.withMode(AppRoutingMode.onlySelected);
      expect(onlySome.inForce, {'b'});

      final back = onlySome.withMode(AppRoutingMode.allExcept);
      expect(back.inForce, {'a'});
    });

    test('should list every app picked in either mode as ever picked', () {
      const selection = AppRoutingSelection(
        allExcept: {'a'},
        onlySelected: {'b'},
      );

      expect(selection.everPicked, {'a', 'b'});
    });

    test('should replace only the list in force', () {
      const selection = AppRoutingSelection(
        mode: AppRoutingMode.onlySelected,
        allExcept: {'a'},
        onlySelected: {'b'},
      );

      final next = selection.withInForce({'c'});

      expect(next.onlySelected, {'c'});
      expect(next.allExcept, {'a'});
      expect(next.mode, AppRoutingMode.onlySelected);
    });

    test(
      'should send every app through the VPN when nothing is picked in only-some mode',
      () {
        const empty = AppRoutingSelection(mode: AppRoutingMode.onlySelected);
        const picked = AppRoutingSelection(
          mode: AppRoutingMode.onlySelected,
          onlySelected: {'y'},
        );
        const excepted = AppRoutingSelection(allExcept: {'a'});

        expect(empty.usesVpn('x'), isTrue);
        expect(picked.usesVpn('x'), isFalse);
        expect(picked.usesVpn('y'), isTrue);
        expect(excepted.usesVpn('a'), isFalse);
        expect(excepted.usesVpn('x'), isTrue);
      },
    );

    test(
      'should resolve to none when disabled or the list in force is empty',
      () {
        const empty = AppRoutingSelection(mode: AppRoutingMode.onlySelected);
        const picked = AppRoutingSelection(
          mode: AppRoutingMode.onlySelected,
          onlySelected: {'a'},
        );

        expect(picked.routingWhen(enabled: false), AppRouting.none);
        expect(empty.routingWhen(enabled: true), AppRouting.none);
        expect(
          picked.routingWhen(enabled: true),
          const AppRouting(mode: AppRoutingMode.onlySelected, apps: ['a']),
        );
      },
    );
  });
}
