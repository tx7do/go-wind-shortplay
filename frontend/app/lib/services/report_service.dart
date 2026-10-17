import '../core/network/api_client.dart';

/// 举报服务。
class ReportService {
  ReportService(this._api);

  final ApiClient _api;

  /// 举报原因选项（label 为展示文案，value 提交后端）。
  static const List<(String, String)> reasons = [
    ('违法违规', 'ILLEGAL'),
    ('色情低俗', 'PORNOGRAPHY'),
    ('侵权', 'INFRINGEMENT'),
    ('人身攻击', 'PERSONAL_ATTACK'),
    ('其他', 'OTHER'),
  ];

  /// 提交举报；targetType：1 视频 / 2 评论 / 3 用户。
  ///
  /// 409 DUPLICATE_REPORT 由 UI 层做友好提示。
  Future<void> report({
    required int targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    await _api.postJson(
      '/reports',
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
  }
}
