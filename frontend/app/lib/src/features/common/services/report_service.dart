import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';

/// 举报目标类型（protojson 枚举字符串全名）
class ReportTargetType {
  ReportTargetType._();

  static const video = 'REPORT_TARGET_TYPE_VIDEO';
  static const comment = 'REPORT_TARGET_TYPE_COMMENT';
  static const user = 'REPORT_TARGET_TYPE_USER';
}

/// 举报服务：提交举报工单
class ReportService extends BaseService {
  ReportService() : super(tag: 'ReportService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 提交举报
  ///
  /// [reason] 为原因枚举码，UI 层用预置原因；409 DUPLICATE_REPORT 由调用方
  /// 捕获 [ApiStatusException] 判断提示。
  Future<void> create({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    try {
      await _dio.post<Object?>(
        '/reports',
        data: {
          'targetType': targetType,
          'targetId': targetId,
          'reason': reason,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
