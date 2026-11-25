import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The grip at the top edge of a sheet, with the gap above it.
///
/// One drawing for every sheet that has one, so no two sheets drift into
/// different grips. The server picker is the one sheet with a grip today.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppLayout.sheetHandleTop.h),
      child: Container(
        width: AppLayout.sheetHandleWidth.w,
        height: AppLayout.sheetHandleHeight.h,
        decoration: BoxDecoration(
          color: context.palette.lineStrong,
          borderRadius: BorderRadius.circular(AppLayout.sheetHandleRadius.r),
        ),
      ),
    );
  }
}
