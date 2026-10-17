import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';

/// 视频详情（app.service.v1 GET /videos/{id}）
class VideoDetail {
  final Video video;
  final UserBrief? author;

  /// 作者统计：{videoCount, followerCount, followingCount, likeReceivedCount}
  final UserStats? authorStats;

  const VideoDetail({
    required this.video,
    this.author,
    this.authorStats,
  });

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    final video = json['video'];
    final author = json['author'];
    final stats = json['authorStats'];
    return VideoDetail(
      video: video is Map<String, dynamic>
          ? Video.fromJson(video)
          : const Video(id: 0),
      author: author is Map<String, dynamic> ? UserBrief.fromJson(author) : null,
      authorStats:
          stats is Map<String, dynamic> ? UserStats.fromJson(stats) : null,
    );
  }
}

/// 视频服务：详情 / 编辑 / 删除（本人）
class VideoService extends BaseService {
  VideoService() : super(tag: 'VideoService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 单视频详情（游客可访问）：{video, author, authorStats, viewerState}
  Future<VideoDetail> getDetail({required int videoId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/videos/$videoId');
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return VideoDetail.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 编辑本人视频 {title?, description?, tags[]}
  Future<Video> update({
    required int videoId,
    String? title,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/videos/$videoId',
        data: {
          'title': ?title,
          'description': ?description,
          'tags': ?tags,
        },
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

  /// 删除本人视频
  Future<void> delete(int videoId) async {
    try {
      await _dio.delete<Object?>('/videos/$videoId');
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
