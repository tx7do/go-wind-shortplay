import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/core/utilities/media_url.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 草稿（video.service.v1.VideoDraft）
class VideoDraft {
  final int id;
  final String title;
  final String description;
  final List<String> tags;
  final String coverUrl;
  final String videoUrl;
  final int duration;
  final String uploadTaskId;
  final DateTime? createdAt;

  /// 挂靠剧集（提交发布时服务端按此挂靠；episodeNumber 0=自动排号）
  final int seriesId;
  final int episodeNumber;

  const VideoDraft({
    required this.id,
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.coverUrl = '',
    this.videoUrl = '',
    this.duration = 0,
    this.uploadTaskId = '',
    this.createdAt,
    this.seriesId = 0,
    this.episodeNumber = 0,
  });

  factory VideoDraft.fromJson(Map<String, dynamic> json) {
    return VideoDraft(
      id: jsonInt(json['id']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      coverUrl: jsonString(json['coverUrl']),
      videoUrl: jsonString(json['videoUrl']),
      duration: jsonInt(json['duration']),
      uploadTaskId: jsonString(json['uploadTaskId']),
      createdAt: parseTime(json['createdAt']),
      seriesId: jsonInt(json['seriesId']),
      episodeNumber: jsonInt(json['episodeNumber']),
    );
  }

  String get coverDisplayUrl => MediaUrl.resolve(coverUrl);
}

/// 草稿服务：草稿列表 / 提交发布 / 删除
class DraftService extends BaseService {
  DraftService() : super(tag: 'DraftService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 草稿列表
  Future<PageData<VideoDraft>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/drafts',
        queryParameters: const {'pageNum': 1, 'pageSize': 50},
      );
      final data = res.data ?? const {};
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VideoDraft.fromJson)
          .toList();
      return PageData(
        items: items,
        total: jsonInt(data['total'], fallback: items.length),
      );
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 草稿提交发布（人工审核开 → REVIEWING；关 → PUBLISHED）→ Video
  Future<Video> submit(int draftId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/drafts/$draftId/submit',
        data: const {},
      );
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return Video.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 删除草稿
  Future<void> delete(int draftId) async {
    try {
      await _dio.delete<Object?>('/drafts/$draftId');
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
