import 'package:shortplay_app/src/core/utilities/convert.dart';
import 'package:shortplay_app/src/core/utilities/media_url.dart';

/// 视频状态（protojson 枚举为字符串全名）
class VideoStatus {
  VideoStatus._();

  static const draft = 'VIDEO_STATUS_DRAFT';
  static const reviewing = 'VIDEO_STATUS_REVIEWING';
  static const published = 'VIDEO_STATUS_PUBLISHED';
  static const rejected = 'VIDEO_STATUS_REJECTED';
  static const offline = 'VIDEO_STATUS_OFFLINE';

  static bool isPublished(String status) => status == published;
}

/// Feed 召回原因
class FeedReason {
  FeedReason._();

  static const follow = 'FEED_REASON_FOLLOW';
  static const hot = 'FEED_REASON_HOT';
  static const latest = 'FEED_REASON_LATEST';
}

/// 视频（video.service.v1.Video）
///
/// protojson 序列化注意：id/authorId/duration/width/height 为数字，
/// likeCount/collectCount/commentCount/viewCount 为字符串。
class Video {
  final int id;
  final String title;
  final String description;
  final String coverUrl;

  /// 视频对象键或完整 URL（展示/播放前需 [playUrl]）
  final String videoUrl;
  final int duration;
  final int width;
  final int height;
  final String status;
  final int authorId;
  final List<String> tags;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final int viewCount;
  final String rejectReason;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  /// 挂靠剧集（0=未挂靠；episodeNumber 为剧内集号，seriesTitle 为展示冗余）
  final int seriesId;
  final int episodeNumber;
  final String seriesTitle;

  /// 查看者互动状态（详情接口 viewerState；列表接口由批量状态查询回填）
  final bool liked;
  final bool collected;
  final bool followingAuthor;

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
    this.publishedAt,
    this.createdAt,
    this.seriesId = 0,
    this.episodeNumber = 0,
    this.seriesTitle = '',
    this.liked = false,
    this.collected = false,
    this.followingAuthor = false,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    final viewer = (json['viewerState'] as Map<String, dynamic>?);
    return Video(
      id: jsonInt(json['id']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      coverUrl: jsonString(json['coverUrl']),
      videoUrl: jsonString(json['videoUrl']),
      duration: jsonInt(json['duration']),
      width: jsonInt(json['width']),
      height: jsonInt(json['height']),
      status: jsonString(json['status'], fallback: VideoStatus.published),
      authorId: jsonInt(json['authorId']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      likeCount: jsonInt(json['likeCount']),
      collectCount: jsonInt(json['collectCount']),
      commentCount: jsonInt(json['commentCount']),
      viewCount: jsonInt(json['viewCount']),
      rejectReason: jsonString(json['rejectReason']),
      publishedAt: parseTime(json['publishedAt']),
      createdAt: parseTime(json['createdAt']),
      seriesId: jsonInt(json['seriesId']),
      episodeNumber: jsonInt(json['episodeNumber']),
      seriesTitle: jsonString(json['seriesTitle']),
      liked: jsonBool(viewer?['liked']),
      collected: jsonBool(viewer?['collected']),
      followingAuthor: jsonBool(viewer?['following']),
    );
  }

  /// 可播放地址（对象键 → 媒体网关 URL）
  String get playUrl => MediaUrl.resolve(videoUrl);

  /// 封面地址（对象键 → 媒体网关 URL）
  String get coverDisplayUrl => MediaUrl.resolve(coverUrl);

  Video copyWith({
    String? title,
    String? description,
    int? likeCount,
    int? collectCount,
    int? commentCount,
    int? viewCount,
    bool? liked,
    bool? collected,
    bool? followingAuthor,
  }) {
    return Video(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl,
      videoUrl: videoUrl,
      duration: duration,
      width: width,
      height: height,
      status: status,
      authorId: authorId,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      collectCount: collectCount ?? this.collectCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      rejectReason: rejectReason,
      publishedAt: publishedAt,
      createdAt: createdAt,
      liked: liked ?? this.liked,
      collected: collected ?? this.collected,
      followingAuthor: followingAuthor ?? this.followingAuthor,
    );
  }
}

/// Feed 条目（feed.service.v1 项）
class FeedItem {
  final Video video;

  /// 召回原因：FEED_REASON_FOLLOW/HOT/LATEST
  final String reason;

  const FeedItem({required this.video, this.reason = FeedReason.latest});

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final video = json['video'];
    return FeedItem(
      video: video is Map<String, dynamic>
          ? Video.fromJson(video)
          : const Video(id: 0),
      reason: jsonString(json['reason'], fallback: FeedReason.latest),
    );
  }
}

/// 用户摘要（identity.service.v1.UserBrief）
class UserBrief {
  final int id;
  final String nickname;
  final String avatarUrl;

  const UserBrief({
    required this.id,
    this.nickname = '',
    this.avatarUrl = '',
  });

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: jsonInt(json['id']),
      nickname: jsonString(json['nickname']),
      avatarUrl: jsonString(json['avatarUrl']),
    );
  }

  /// 头像展示地址
  String get avatarDisplayUrl => MediaUrl.resolve(avatarUrl);
}

/// 用户资料（identity.service.v1.User）
class UserProfile {
  final int id;
  final String username;
  final String nickname;
  final String avatarUrl;
  final String bio;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.username = '',
    this.nickname = '',
    this.avatarUrl = '',
    this.bio = '',
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: jsonInt(json['id']),
      username: jsonString(json['username']),
      nickname: jsonString(json['nickname']),
      avatarUrl: jsonString(json['avatarUrl']),
      bio: jsonString(json['bio']),
      createdAt: parseTime(json['createdAt']),
    );
  }

  UserBrief get brief =>
      UserBrief(id: id, nickname: nickname, avatarUrl: avatarUrl);

  /// 头像展示地址
  String get avatarDisplayUrl => MediaUrl.resolve(avatarUrl);
}

/// 用户统计（identity.service.v1.UserStats）
class UserStats {
  final int userId;
  final int videoCount;
  final int followerCount;
  final int followingCount;
  final int likeReceivedCount;

  const UserStats({
    required this.userId,
    this.videoCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.likeReceivedCount = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: jsonInt(json['userId']),
      videoCount: jsonInt(json['videoCount']),
      followerCount: jsonInt(json['followerCount']),
      followingCount: jsonInt(json['followingCount']),
      likeReceivedCount: jsonInt(json['likeReceivedCount']),
    );
  }
}

/// 创作者中心总览（stats.service.v1.CreatorOverview）
class CreatorOverview {
  final int videoCount;
  final int totalViews;
  final int totalLikes;
  final int totalCollects;
  final int totalComments;
  final int followerCount;

  const CreatorOverview({
    this.videoCount = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalCollects = 0,
    this.totalComments = 0,
    this.followerCount = 0,
  });

  factory CreatorOverview.fromJson(Map<String, dynamic> json) {
    return CreatorOverview(
      videoCount: jsonInt(json['videoCount']),
      totalViews: jsonInt(json['totalViews']),
      totalLikes: jsonInt(json['totalLikes']),
      totalCollects: jsonInt(json['totalCollects']),
      totalComments: jsonInt(json['totalComments']),
      followerCount: jsonInt(json['followerCount']),
    );
  }
}

/// 视频互动状态（interaction.service.v1.InteractionStatus）
class InteractionStatus {
  final bool liked;
  final bool collected;

  const InteractionStatus({this.liked = false, this.collected = false});

  factory InteractionStatus.fromJson(Map<String, dynamic> json) {
    return InteractionStatus(
      liked: jsonBool(json['liked']),
      collected: jsonBool(json['collected']),
    );
  }
}

/// 标签（video.service.v1.Tag）
class VideoTag {
  final int id;
  final String name;
  final int videoCount;

  const VideoTag({required this.id, this.name = '', this.videoCount = 0});

  factory VideoTag.fromJson(Map<String, dynamic> json) {
    return VideoTag(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      videoCount: jsonInt(json['videoCount']),
    );
  }
}

/// 剧集（series.service.v1.Series）
///
/// 集数（episodeCount/publishedCount）为服务端实时派生的 int64（字符串形态）。
class Series {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final int authorId;
  final int episodeCount;
  final int publishedCount;
  final DateTime? createdAt;

  const Series({
    required this.id,
    this.title = '',
    this.description = '',
    this.coverUrl = '',
    this.authorId = 0,
    this.episodeCount = 0,
    this.publishedCount = 0,
    this.createdAt,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: jsonInt(json['id']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      coverUrl: jsonString(json['coverUrl']),
      authorId: jsonInt(json['authorId']),
      episodeCount: jsonInt(json['episodeCount']),
      publishedCount: jsonInt(json['publishedCount']),
      createdAt: parseTime(json['createdAt']),
    );
  }

  /// 封面地址（对象键 → 媒体网关 URL）
  String get coverDisplayUrl => MediaUrl.resolve(coverUrl);
}

/// 剧集详情（series.service.v1.SeriesDetail：剧信息 + 选集，集号升序）
class SeriesDetail {
  final Series? series;
  final List<Video> items;

  const SeriesDetail({this.series, this.items = const []});

  factory SeriesDetail.fromJson(Map<String, dynamic> json) {
    return SeriesDetail(
      series: json['series'] is Map<String, dynamic>
          ? Series.fromJson(json['series'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Video.fromJson)
          .toList(),
    );
  }
}

/// 单日趋势点（stats.service.v1.TrendItem）
class TrendPoint {
  final String date;
  final int published;
  final int plays;
  final int likes;

  const TrendPoint({
    this.date = '',
    this.published = 0,
    this.plays = 0,
    this.likes = 0,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: jsonString(json['date']),
      published: jsonInt(json['published']),
      plays: jsonInt(json['plays']),
      likes: jsonInt(json['likes']),
    );
  }
}

/// 解析 protojson 时间戳（RFC3339 字符串）
DateTime? parseTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
