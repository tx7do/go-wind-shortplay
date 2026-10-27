import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 弹幕（danmaku.service.v1.Danmaku）
class DanmakuItem {
  final int id;
  final int userId;

  /// 发送人（冗余展示）
  final UserBrief? user;
  final String content;

  /// 视频时间轴偏移（毫秒）
  final int timeOffsetMs;

  const DanmakuItem({
    required this.id,
    this.userId = 0,
    this.user,
    this.content = '',
    this.timeOffsetMs = 0,
  });

  factory DanmakuItem.fromJson(Map<String, dynamic> json) {
    return DanmakuItem(
      id: jsonInt(json['id']),
      userId: jsonInt(json['userId']),
      user: json['user'] is Map<String, dynamic>
          ? UserBrief.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      content: jsonString(json['content']),
      timeOffsetMs: jsonInt(json['timeOffsetMs']),
    );
  }
}

/// 弹幕服务：发送（需登录）/ 视频弹幕拉取（游客可访问，尽力而为）
class DanmakuService extends BaseService {
  DanmakuService() : super(tag: 'DanmakuService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 视频弹幕（VISIBLE，按时间轴偏移升序；失败返回空）
  Future<List<DanmakuItem>> list(int videoId, {int limit = 500}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/videos/$videoId/danmaku',
        queryParameters: {'limit': limit},
      );
      return (res.data?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DanmakuItem.fromJson)
          .toList();
    } on DioException {
      return const [];
    }
  }

  /// 发送弹幕（返回落库后的弹幕；敏感词/开关关闭会抛 ApiStatusException）
  Future<DanmakuItem> send({
    required int videoId,
    required String content,
    required int timeOffsetMs,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/videos/$videoId/danmaku',
        data: {'content': content, 'timeOffsetMs': '$timeOffsetMs'},
      );
      return DanmakuItem.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
