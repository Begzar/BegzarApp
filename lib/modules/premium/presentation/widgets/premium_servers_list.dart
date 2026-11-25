import 'package:begzar/core/widgets/app_buttons.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/soft_enter.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_connect_action.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_card.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_servers_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// The premium server picker, shown inside the home screen's picker sheet.
///
/// It used to be the home body itself, floated in a Stack under the IP and
/// ping readings, and carried a bottom inset derived from how far up the
/// screen those readings reached. In a sheet nothing is in front of it, so the
/// inset — and the coupling to another widget's layout — is gone.
/// The glyph an empty list shows after a failed load — a warning tint, with
/// the rim doing the work, the same way the error banner is built.
const _noticeFillAlpha = 0.15;
const _noticeRimAlpha = 0.45;

class PremiumServersList extends ConsumerStatefulWidget {
  const PremiumServersList({super.key});

  @override
  ConsumerState<PremiumServersList> createState() => _PremiumServersListState();
}

class _PremiumServersListState extends ConsumerState<PremiumServersList>
    with PremiumConnectAction {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumServersProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serversState = ref.watch(premiumServersProvider);
    final connectionState = ref.watch(connectionProvider);
    final isConnected = connectionState.status == ConnectionStatus.connected;
    final isDisconnecting =
        connectionState.status == ConnectionStatus.disconnecting;
    final isBusy =
        connectionState.status == ConnectionStatus.connecting ||
        isDisconnecting;

    _listenForErrors();

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.premiumListPadH.w,
          0,
          AppLayout.premiumListPadH.w,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftEnter(
              visible: true,
              duration: PremiumPalette.entrance,
              slide: const Offset(0, -0.12),
              alignment: Alignment.centerLeft,
              child: PremiumServersHeader(
                state: serversState,
                isConnected: isConnected || isDisconnecting,
                isBusy: isBusy,
              ),
            ),
            SizedBox(height: AppLayout.premiumListHeaderGap.h),
            Expanded(child: _buildBody(l10n, serversState, isBusy)),
          ],
        ),
      ),
    );
  }

  /// A new failure gets one popup. Repeating the same key would re-announce a
  /// failure the user has already seen on every rebuild.
  void _listenForErrors() {
    ref.listen(premiumServersProvider, (previous, next) {
      final newError = next.errorMessage;
      if (newError == null || newError == previous?.errorMessage) return;
      if (!mounted) return;
      showTopErrorPopup(context, newError);
    });
  }

  Widget _buildBody(
    AppLocalizations l10n,
    PremiumServersState state,
    bool isBusy,
  ) {
    final palette = PremiumPalette.of(context);

    if (state.isLoading && !state.hasLoaded) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: palette.primary,
          size: AppLayout.premiumListFlag.w,
        ),
      );
    }

    // A failure with servers already on screen keeps them — the popup above
    // has already said the refresh did not land.
    if (state.errorMessage != null && state.servers.isEmpty) {
      return _EmptyWithError(isBusy: state.isLoading);
    }

    if (state.servers.isEmpty) {
      return Center(
        child: Text(
          l10n.premiumServersEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textTertiary,
            fontSize: AppLayout.textXl.sp,
            fontWeight: FontWeight.w300,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: AppLayout.premiumListBottomPad.h),
      itemCount: state.servers.length,
      separatorBuilder: (_, _) =>
          SizedBox(height: AppLayout.premiumListRowGap.h),
      itemBuilder: (context, index) {
        final server = state.servers[index];
        return SoftListItem(
          index: index,
          child: PremiumServerCard(
            server: server,
            expanded: state.expandedServerId == server.id,
            state: state,
            isBusy: isBusy,
            onToggle: () => ref
                .read(premiumServersProvider.notifier)
                .toggleExpanded(server.id),
            onSelectConfig: (config) => selectConfig(config, server),
          ),
        );
      },
    );
  }
}

/// Nothing loaded, and the load failed. The error toast says why; this keeps
/// the way to ask again once the toast has gone.
class _EmptyWithError extends ConsumerWidget {
  const _EmptyWithError({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppLayout.premiumEmptyPadH.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppLayout.premiumListEmptyIcon.w,
              height: AppLayout.premiumListEmptyIcon.w,
              decoration: BoxDecoration(
                color: palette.amber.withValues(alpha: _noticeFillAlpha),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.amber.withValues(alpha: _noticeRimAlpha),
                ),
              ),
              child: Icon(
                Iconsax.warning_2,
                color: palette.amberInk,
                size: AppLayout.premiumEmptyGlyphGap.sp,
              ),
            ),
            SizedBox(height: AppLayout.premiumEmptyActionGap.h),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: l10n.tryAgain,
                color: palette.primary,
                isLoading: isBusy,
                onPressed: isBusy
                    ? null
                    : () => ref
                          .read(premiumServersProvider.notifier)
                          .load(force: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
