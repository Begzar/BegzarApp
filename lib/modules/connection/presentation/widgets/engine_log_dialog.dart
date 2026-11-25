import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass_dialog.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:begzar/modules/connection/presentation/controllers/engine_log_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Opens the engine log: what Xray, WARP and the engine say, as they say it.
///
/// A diagnostic tool, reached by tapping the wordmark seven times rather than
/// from any menu. Every line was redacted by the engine before it was kept,
/// so what it shows and exports carries no link, key, server or address.
Future<void> showEngineLogDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
    builder: (_) => const EngineLogDialog(),
  );
}

class EngineLogDialog extends ConsumerStatefulWidget {
  const EngineLogDialog({super.key});

  @override
  ConsumerState<EngineLogDialog> createState() => _EngineLogDialogState();
}

class _EngineLogDialogState extends ConsumerState<EngineLogDialog> {
  final _scroll = ScrollController();
  final _exportKey = GlobalKey();

  /// Follows new lines while the reader is at the bottom; scrolling up to
  /// read stops it, and scrolling back down starts it again.
  bool _following = true;

  /// How many lines the last build showed, to tell when new ones arrived.
  int _shownCount = 0;

  /// How close to the bottom still counts as at it.
  static const _followSlack = 24.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      _following = position.maxScrollExtent - position.pixels <= _followSlack;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followToBottom() {
    if (!_following) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _clear() async {
    final failureKey = await ref.read(engineLogProvider.notifier).clear();
    if (!mounted) return;
    if (failureKey != null) showTopErrorPopup(context, failureKey);
    _following = true;
  }

  Future<void> _export() async {
    final result = await ref
        .read(engineLogProvider.notifier)
        .export(shareOrigin: _originOf(_exportKey));
    if (!mounted) return;
    if (result.failureKey != null) {
      showTopErrorPopup(context, result.failureKey);
    } else if (result.outcome == EngineLogExportOutcome.saved) {
      showTopNoticePopup(context, context.l10n.engineLogSaved);
    }
  }

  /// Where the share sheet points from on an iPad: the Export button.
  static Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final state = ref.watch(engineLogProvider);
    final notifier = ref.read(engineLogProvider.notifier);
    final visible = state.visible;

    // New lines, or a different filter: keep the newest in view.
    if (visible.length != _shownCount) {
      _shownCount = visible.length;
      _followToBottom();
    }

    return AppGlassDialog(
      padding: EdgeInsets.all(AppLayout.gap16.w),
      insetPadding: EdgeInsets.symmetric(
        horizontal: AppLayout.gap12.w,
        vertical: AppLayout.gap24.h,
      ),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.engineLogTitle,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: AppLayout.text3xl.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.engineLogClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Iconsax.close_circle_copy,
                    color: palette.textSecondary,
                    size: AppLayout.text4xl.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppLayout.gap8.h),
            _FilterRow(selected: state.filter, onSelected: notifier.showOnly),
            if (state.unavailable || state.dropped) ...[
              SizedBox(height: AppLayout.gap8.h),
              Text(
                state.unavailable
                    ? l10n.errEngineLogUnavailable
                    : l10n.engineLogDropped,
                style: TextStyle(
                  color: palette.warning,
                  fontSize: AppLayout.textMd.sp,
                ),
              ),
            ],
            SizedBox(height: AppLayout.gap8.h),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: palette.page,
                  borderRadius: BorderRadius.circular(AppLayout.radiusLg.r),
                  border: Border.all(color: palette.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          l10n.engineLogEmpty,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: AppLayout.textLg.sp,
                          ),
                        ),
                      )
                    : SelectionArea(
                        // Log text reads left to right in every language.
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.all(AppLayout.gap8.w),
                            itemCount: visible.length,
                            itemBuilder: (_, index) =>
                                _LogLineView(line: visible[index]),
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(height: AppLayout.gap12.h),
            Row(
              children: [
                Expanded(
                  child: InkQuietButton(
                    label: l10n.engineLogClear,
                    onPressed: state.busy ? null : _clear,
                  ),
                ),
                SizedBox(width: AppLayout.inkActionsGap.w),
                Expanded(
                  flex: 2,
                  child: InkFilledButton(
                    key: _exportKey,
                    label: l10n.engineLogExport,
                    color: palette.accent,
                    leading: Icon(
                      Iconsax.export_copy,
                      size: AppLayout.textXl.sp,
                    ),
                    onPressed: state.busy || visible.isEmpty ? null : _export,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// All, then one choice per component.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final EngineLogComponent? selected;
  final ValueChanged<EngineLogComponent?> onSelected;

  // Xray and WARP are the engines' own names, the same in every language.
  static String _label(AppLocalizations l10n, EngineLogComponent component) =>
      switch (component) {
        EngineLogComponent.xray => 'Xray',
        EngineLogComponent.warp => 'WARP',
        EngineLogComponent.engine => l10n.engineLogEngine,
      };

  @override
  Widget build(BuildContext context) {
    final choices = <(EngineLogComponent?, String)>[
      (null, context.l10n.engineLogAll),
      for (final c in EngineLogComponent.values) (c, _label(context.l10n, c)),
    ];
    return Wrap(
      spacing: AppLayout.gap6.w,
      runSpacing: AppLayout.gap6.h,
      children: [
        for (final (component, label) in choices)
          _FilterPill(
            label: label,
            selected: component == selected,
            onTap: () => onSelected(component),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.gap12.w,
          vertical: AppLayout.gap6.h,
        ),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.16)
              : palette.surface,
          borderRadius: BorderRadius.circular(AppLayout.radiusPill.r),
          border: Border.all(color: selected ? palette.accent : palette.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.accent : palette.textSecondary,
            fontSize: AppLayout.textMd.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LogLineView extends StatelessWidget {
  const _LogLineView({required this.line});

  final EngineLogLine line;

  static String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final levelColor = switch (line.level) {
      EngineLogLevel.error => palette.failed,
      EngineLogLevel.warn => palette.warning,
      EngineLogLevel.info => palette.textSecondary,
      EngineLogLevel.debug => palette.muted,
    };
    final where = line.fromTunnel
        ? '${line.component.name}@tunnel'
        : line.component.name;
    final style = TextStyle(
      fontFamily: AppFaces.mono,
      fontSize: AppLayout.textSm.sp,
      height: 1.35,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppLayout.gap2.h),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '${_clock(line.time)} ',
              style: TextStyle(color: palette.muted),
            ),
            TextSpan(
              text: '$where ',
              style: TextStyle(color: palette.accent),
            ),
            TextSpan(
              text: line.message,
              style: TextStyle(color: levelColor),
            ),
          ],
        ),
      ),
    );
  }
}
