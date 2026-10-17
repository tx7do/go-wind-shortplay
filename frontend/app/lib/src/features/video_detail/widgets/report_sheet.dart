import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/services/report_service.dart';

/// 预置举报原因（UI 层枚举 → 后端 reason 枚举码，服务端透传存储）
class ReportReasonOption {
  final String code;
  final String Function(S loc) label;

  const ReportReasonOption(this.code, this.label);

  static List<ReportReasonOption> presets(S loc) => [
        ReportReasonOption('porn', (l) => l.reportReasonPorn),
        ReportReasonOption('violence', (l) => l.reportReasonViolence),
        ReportReasonOption('abuse', (l) => l.reportReasonAbuse),
        ReportReasonOption('copyright', (l) => l.reportReasonCopyright),
        ReportReasonOption('fraud', (l) => l.reportReasonFraud),
        ReportReasonOption('other', (l) => l.reportReasonOther),
      ];
}

/// 举报 BottomSheet：原因选择 + 补充说明 → POST /reports
///
/// 409 DUPLICATE_REPORT 单独提示。
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required int targetId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _ReportSheet(targetType: targetType, targetId: targetId);
    },
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final int targetId;

  const _ReportSheet({required this.targetType, required this.targetId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selected;
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = S.of(context);
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ReportService().create(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selected!,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      EasyLoading.showToast(loc.reportSubmitted);
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      if (e.status.reason == 'DUPLICATE_REPORT') {
        EasyLoading.showToast(loc.reportDuplicate);
      } else {
        EasyLoading.showToast(loc.errorDefault);
      }
    } catch (_) {
      EasyLoading.showToast(loc.errorDefault);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.reportReasonTitle,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12.h),
            // RadioGroup 统一管理选中态（Flutter 3.32+ 推荐）
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) => setState(() => _selected = value),
              child: Column(
                children: ReportReasonOption.presets(loc)
                    .map(
                      (option) => RadioListTile<String>(
                        value: option.code,
                        title: Text(
                          option.label(loc),
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: TextStyle(fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: loc.reportDescriptionHint,
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: FilledButton(
                onPressed: _selected == null ? null : _submit,
                child: Text(_submitting ? loc.loading : loc.reportSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
