import 'dart:async';

import 'package:begzar/core/domain/surface_mood.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_buttons.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/notifications/application/services/firebase_service.dart';
import 'package:begzar/modules/notifications/data/datasources/notification_permission_service.dart';
import 'package:begzar/modules/notifications/presentation/notifications_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Blocks app usage until notification permission is granted.
class NotificationPermissionGate extends ConsumerStatefulWidget {
  const NotificationPermissionGate({
    super.key,
    required this.child,
    this.permissionService,
  });

  final Widget child;

  /// The platform's permission, for a test to stand in for.
  final NotificationPermissionService? permissionService;

  /// The bare page shown while the platform is asked.
  static const waitingKey = Key('notification-permission-waiting');

  @override
  ConsumerState<NotificationPermissionGate> createState() =>
      _NotificationPermissionGateState();
}

class _NotificationPermissionGateState
    extends ConsumerState<NotificationPermissionGate>
    with WidgetsBindingObserver {
  late final _permissionService =
      widget.permissionService ?? NotificationPermissionService();
  bool? _granted;
  bool _requesting = false;
  bool _needsSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionState();
    }
  }

  Future<void> _refreshPermissionState() async {
    final granted = await _permissionService.isGranted();
    if (!mounted) return;

    final needsSettings = granted
        ? false
        : await _permissionService.shouldOpenSettings();

    if (!mounted) return;

    setState(() {
      _granted = granted;
      _needsSettings = needsSettings;
    });

    if (granted) {
      unawaited(_prepareMessagingInBackground());
    } else {
      // The question is a screen of its own, with no home dial for the
      // launch cover to land on.
      ref.read(launchCoverProvider.notifier).dismiss();
    }
  }

  Future<void> _prepareMessagingInBackground() async {
    await FirebaseService().ensureMessagingReady();
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);

    final granted = await _permissionService.request();
    final needsSettings =
        !granted && await _permissionService.shouldOpenSettings();

    if (!mounted) return;

    setState(() {
      _granted = granted;
      _needsSettings = needsSettings;
      _requesting = false;
    });

    if (granted) {
      unawaited(_prepareMessagingInBackground());
    }
  }

  Future<void> _openSettings() async {
    await _permissionService.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    // Asked on every launch, between the launch window and home, and
    // answered within a few frames. A spinner on the platform's own white
    // flashed in that gap; the bare page is what both sides of it show.
    if (_granted == null) {
      return ColoredBox(
        key: NotificationPermissionGate.waitingKey,
        color: context.palette.page,
      );
    }

    if (_granted!) {
      return widget.child;
    }

    return PopScope(
      canPop: false,
      child: _NotificationPermissionScreen(
        requesting: _requesting,
        needsSettings: _needsSettings,
        onRequest: _requestPermission,
        onOpenSettings: _openSettings,
      ),
    );
  }
}

class _NotificationPermissionScreen extends StatelessWidget {
  const _NotificationPermissionScreen({
    required this.requesting,
    required this.needsSettings,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final bool requesting;
  final bool needsSettings;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  /// The bell on its disc.
  Widget _mark(NotificationsPalette palette) {
    return Container(
      width: AppLayout.notifyGateMarkSize.w,
      height: AppLayout.notifyGateMarkSize.w,
      decoration: BoxDecoration(
        color: palette.markFill,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Iconsax.notification_bing_copy,
        color: palette.accent,
        size: AppLayout.notifyGateMarkGlyph.sp,
      ),
    );
  }

  /// The way out when the system has stopped asking on the app's behalf.
  Widget _settingsHint(NotificationsPalette palette, AppLocalizations l10n) {
    return Text(
      l10n.notificationPermissionSettingsHint,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: palette.textTertiary,
        fontSize: AppLayout.notifyGateHint.sp,
        height: AppLayout.notifyGateHintLineHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = NotificationsPalette.of(context);

    // The same gradient every other screen paints, asked for by mood rather
    // than copied. The three stops used to be written out here by hand, and
    // the copy had lost the weighting that holds the middle colour over most
    // of the screen — so the first screen a new install saw was visibly
    // lighter than every screen after it.
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: context.palette.pageGradient(SurfaceMood.idle),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.notifyGateInsetH.w,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _mark(palette),
                SizedBox(height: AppLayout.notifyGateMarkToTitle.h),
                Text(
                  l10n.notificationPermissionTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: AppLayout.notifyGateTitle.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppLayout.notifyGateTitleToBody.h),
                Text(
                  l10n.notificationPermissionMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: AppLayout.notifyGateBody.sp,
                    height: AppLayout.notifyGateBodyLineHeight,
                  ),
                ),
                SizedBox(height: AppLayout.notifyGateBodyToAction.h),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: needsSettings
                        ? l10n.openNotificationSettings
                        : l10n.enableNotifications,
                    color: palette.accent,
                    onColor: palette.onAccent,
                    isLoading: requesting,
                    onPressed: needsSettings ? onOpenSettings : onRequest,
                  ),
                ),
                SizedBox(height: AppLayout.notifyGateActionGap.h),
                if (needsSettings)
                  _settingsHint(palette, l10n)
                else
                  TextButton(
                    onPressed: onOpenSettings,
                    child: Text(
                      l10n.openNotificationSettings,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: AppLayout.notifyGateHint.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
