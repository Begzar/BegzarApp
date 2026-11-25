import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/support/telegram_mark.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/widgets/plan_badge.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/widgets/engine_log_dialog.dart';
import 'package:begzar/modules/main/domain/news_channel.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/tap_streak.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

/// The top row every tab opens with: the app's name and plan on one side,
/// the controls on the other. Each tab draws its own, at the same inset, so
/// switching tabs leaves it where it was.
class HomeAppBar extends ConsumerWidget {
  const HomeAppBar({super.key});

  static const _tapRing =
      (MainPalette.appBarTapTarget - MainPalette.appBarButtonSize) / 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEntitled = ref.watch(
      premiumProvider.select((state) => state.isEntitled),
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: AppLayout.mainAppBarTopInset.h,
        start: AppLayout.mainAppBarEdgeInset.w,
        end: (AppLayout.mainAppBarEdgeInset - _tapRing).w,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const _Wordmark(),
              SizedBox(width: AppLayout.mainAppBarPlanBadgeGap.w),
              PlanBadge(isPremium: isEntitled),
            ],
          ),
          // The name and plan keep their width; on a narrow screen or a long
          // translation it is the support label that gives way.
          const Flexible(child: _ChannelButton()),
        ],
      ),
    );
  }
}

/// The app's name. Seven quick taps on it open the engine log, a diagnostic
/// tool kept out of every menu.
class _Wordmark extends StatefulWidget {
  const _Wordmark();

  @override
  State<_Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<_Wordmark> {
  static const _weight = FontWeight.w600;

  final _taps = TapStreak();

  void _onTap() {
    if (_taps.tap(DateTime.now())) showEngineLogDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: _wordmark(context),
    );
  }

  Widget _wordmark(BuildContext context) {
    return SizedBox(
      height: AppLayout.mainAppBarWordmarkHeight.w,
      child: Center(
        child: Text(
          context.l10n.appName,
          style: TextStyle(
            color: MainPalette.of(context).appBarInk,
            fontFamily: displayFamilyOf(context),
            fontSize: AppLayout.textWordmark.sp,
            fontWeight: _weight,
            letterSpacing:
                joinsLetters(DefaultTextStyle.of(context).style.fontFamily)
                ? null
                : AppLayout.mainAppBarWordmarkTracking,
          ),
        ),
      ),
    );
  }
}

/// The support button: a dark pill with a hairline rim, carrying Telegram's
/// plane and the word for what it opens. The plane alone did not say that the
/// channel is where support is asked for.
class _ChannelButton extends ConsumerWidget {
  const _ChannelButton();

  /// Asks the purchase region service where the device is, so the channel and
  /// the premium link always agree; its address answer is usually already
  /// held from launch.
  Future<void> _openChannel(WidgetRef ref) async {
    final status = ref.read(connectionProvider).status;
    final region = await ref
        .read(purchaseRegionServiceProvider)
        .resolve(tunnelIsUp: status.isActive || status.isTransitional);
    await launchUrl(Uri.parse(NewsChannel.forRegion(region).url));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MainPalette.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openChannel(ref),
      // The ring a finger gets beyond the pill, the same all round as the
      // square button this replaced, so the bar keeps its height.
      child: Padding(
        padding: EdgeInsets.all(HomeAppBar._tapRing.w),
        child: Container(
          height: MainPalette.appBarButtonSize.w,
          padding: EdgeInsetsDirectional.only(
            start: AppLayout.mainAppBarChannelPadStart.w,
            end: AppLayout.mainAppBarChannelPadEnd.w,
          ),
          decoration: BoxDecoration(
            color: palette.appBarButtonFill,
            borderRadius: BorderRadius.circular(
              AppLayout.mainAppBarChannelRadius.r,
            ),
            border: Border.all(color: palette.appBarButtonRim),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TelegramMark(
                color: palette.appBarInk,
                size: MainPalette.appBarGlyphSize.sp,
              ),
              SizedBox(width: AppLayout.mainAppBarChannelLabelGap.w),
              Flexible(
                child: Text(
                  context.l10n.homeSupport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: AppLayout.mainAppBarChannelLabel.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
