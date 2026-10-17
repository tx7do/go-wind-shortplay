import 'common.dart';
import 'user.dart';

/// 视频状态：1草稿 / 2审核中 / 3已发布 / 4驳回 / 5下架。
class VideoStatus {
  const VideoStatus._();

  static const int draft = 1;
  static const int reviewing = 2;
  static const int published = 3;
  static const int rejected = 4;
  static const int removed = 5;

  static String label(int status) {
    switch (status) {
      case draft:
        return '草稿';
      case reviewing:
        return '审核中';
      case published:
        return '已发布';
      case rejected:
        return '已驳回';
      case removed:
        return '已下架';
      default:
        return '未知';
    }
  }
}

/// 视频对象。
class Video {
  const Video({
    required this.id,
    this.title = '',
    this.description = '',
    this.coverUrl = '',
    this.videoUrl = '',
    this.duration = 0,
    this.width = 0,
    this.height = 0,
    this.status = VideoStatus.published,
    this.authorId = 0,
    this.tags = const [],
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.rejectReason = '',
    this.createdAt = '',
  });

  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String videoUrl;

  /// 时长（秒）。
  final int duration;
  final int width;
  final int height;
  final int status;
  final int authorId;
  final List<String> tags;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final int viewCount;
  final String rejectReason;
  final String createdAt;

  bool get isPublished => status == VideoStatus.published;

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: asInt(json['id'] ?? json['videoId'] ?? json['video_id']),
      title: asStr(json['title']),
      description: asStr(json['description']),
      coverUrl: asStr(json['coverUrl'] ?? json['cover_url']),
      videoUrl: asStr(json['videoUrl'] ?? json['video_url']),
      duration: asInt(json['duration']),
      width: asInt(json['width']),
      height: asInt(json['height']),
      status: asInt(json['status'], VideoStatus.published),
      authorId: asInt(json['authorId'] ?? json['author_id']),
      tags: _parseTags(json['tags']),
      likeCount: asInt(json['likeCount'] ?? json['like_count']),
      collectCount: asInt(json['collectCount'] ?? json['collect_count']),
      commentCount: asInt(json['commentCount'] ?? json['comment_count']),
      viewCount: asInt(json['viewCount'] ?? json['view_count']),
      rejectReason: asStr(json['rejectReason'] ?? json['reject_reason']),
      createdAt: asStr(json['createdAt'] ?? json['created_at']),
    );
  }

  static List<String> _parseTags(Object? raw) {
    if (raw is List) {
      return raw.map((e) => asStr(e)).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.isNotEmpty) return raw.split(',');
    return const [];
  }
}

/// 观看者互动状态（视频详情 viewerState / 批量状态查询）。
class ViewerState {
  const ViewerState({
    this.liked = false,
    this.collected = false,
    this.following = false,
  });

  final bool liked;
  final bool collected;
  final bool following;

  factory ViewerState.fromJson(Map<String, dynamic> json) => ViewerState(
        liked: asBool(json['liked']),
        collected: asBool(json['collected']),
        following: asBool(json['following']),
      );
}

/// 视频详情（GET /videos/{videoId}）。
class VideoDetail {
  const VideoDetail({
    required this.video,
    required this.author,
    this.authorStats,
    this.viewerState = const ViewerState(),
  });

  final Video video;
  final User author;
  final UserStats? authorStats;
  final ViewerState viewerState;

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];
    final statsJson = json['authorStats'] ?? json['author_stats'];
    final viewerJson = json['viewerState'] ?? json['viewer_state'];
    return VideoDetail(
      video: Video.fromJson(
        (json['video'] as Map<String, dynamic>?) ?? json,
      ),
      author: authorJson is Map<String, dynamic>
          ? User.fromJson(authorJson)
          : const User(id: 0),
      authorStats:
          statsJson is Map<String, dynamic> ? UserStats.fromJson(statsJson) : null,
      viewerState: viewerJson is Map<String, dynamic>
          ? ViewerState.fromJson(viewerJson)
          : const ViewerState(),
    );
  }
}

/// Feed 条目（GET /feed：`items[]{video, reason}`）。
class FeedEntry {
  const FeedEntry({required this.video, this.reason = ''});

  final Video video;

  /// 召回理由：FOLLOW / HOT / LATEST。
  final String reason;

  factory FeedEntry.fromJson(Map<String, dynamic> json) => FeedEntry(
        video: Video.fromJson(
          (json['video'] as Map<String, dynamic>?) ?? json,
        ),
        reason: asStr(json['reason']),
      );
}
