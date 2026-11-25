import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/utils/device_lan_ips.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The addresses other devices on the LAN can point at this one.
///
/// Auto-disposed and re-read on demand: the answer changes when the device
/// joins another network, and a stale address is worse than none.
final deviceLanIpsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return getDeviceLanIpv4Addresses();
});

/// Shows where the open SOCKS port can be reached from, one tappable
/// endpoint per interface.
///
/// It appears only while sharing is actually live, so every address on it is
/// one that currently works.
class BypassLanAddressesTile extends ConsumerWidget {
  const BypassLanAddressesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;
    final ipsAsync = ref.watch(deviceLanIpsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsBypassPadH.w,
        AppLayout.settingsBypassPadTop.h,
        AppLayout.settingsBypassPadH.w,
        AppLayout.settingsBypassPadBottom.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.bypassLanAddressesTitle,
                  style: TextStyle(
                    fontSize: AppLayout.textLg.sp,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              InkWell(
                onTap: () => ref.invalidate(deviceLanIpsProvider),
                borderRadius: BorderRadius.circular(AppLayout.radius2xl.r),
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.settingsBypassRefreshPad.w),
                  child: Icon(
                    Iconsax.refresh_copy,
                    size: AppLayout.settingsBypassRefreshGlyph.sp,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.settingsBypassGap.h),
          ipsAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppLayout.settingsBypassRowPadV.h,
              ),
              child: SizedBox(
                width: AppLayout.settingsBypassDot.w,
                height: AppLayout.settingsBypassDot.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.textTertiary,
                ),
              ),
            ),
            // A device with no LAN interface and a lookup that failed read
            // the same on screen: there is nothing to hand out either way.
            error: (_, _) => _NoAddresses(l10n: l10n),
            data: (ips) {
              if (ips.isEmpty) return _NoAddresses(l10n: l10n);

              return Column(
                children: [
                  for (final ip in ips)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: AppLayout.settingsBypassRowGap.h,
                      ),
                      child: _LanEndpointChip(
                        label: l10n.bypassLanEndpoint(
                          ip,
                          ref
                              .watch(connectionRepositoryProvider)
                              .activeSocksPort,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoAddresses extends StatelessWidget {
  const _NoAddresses({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return Text(
      l10n.bypassLanNoAddresses,
      style: TextStyle(
        fontSize: AppLayout.textMd.sp,
        color: palette.textTertiary,
      ),
    );
  }
}

/// One `host:port` the user can copy, since it has to be typed into another
/// device's proxy settings.
class _LanEndpointChip extends StatelessWidget {
  const _LanEndpointChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copy(context),
        borderRadius: BorderRadius.circular(
          AppLayout.settingsDialogFieldRadius.r,
        ),
        child: SizedBox(
          width: double.infinity,
          child: SettingsGlassPanel(
            style: SettingsGlass.chip(
              palette,
              cornerRadius: AppLayout.settingsDialogFieldRadius.r,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.settingsBypassCopyPadH.w,
                vertical: AppLayout.settingsBypassCopyPadV.h,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: AppLayout.textBase.sp,
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    Iconsax.copy_copy,
                    size: AppLayout.settingsBypassCopyGlyph.sp,
                    color: palette.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: label));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 2)),
    );
  }
}
