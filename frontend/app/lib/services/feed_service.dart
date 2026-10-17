import '../core/network/api_client.dart';
import '../models/common.dart';
import '../models/video.dart';
import '../models/user.dart';

/// Feed / 视频详情 / 搜索 / 标签 相关接口。
class FeedService {
  FeedService(this._api);

  final ApiClient _api;

  static const int _pageSize = 10;

  /// 获取推荐流（游客可访问）。tab 仅作为召回渠道标记，
  /// 当前「关注/热门」都走 /feed，为后续服务端按渠道召回留口子。
  Future<PageData<FeedEntry>> feed({
    required int pageNum,
    String? tag,
  }) async {
    final data = await _api.getJson(
      '/feed',
      query: {
        'pageNum': pageNum,
        'pageSize': _pageSize,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    );
    return PageData.parse(
      data,
      parseItem: FeedEntry.fromJson,
      pageNum: pageNum,
      pageSize: _pageSize,
    );
  }

  /// 单视频详情（游客可访问），含作者与观看者互动状态。
  Future<VideoDetail> videoDetail(int videoId) async {
    final data = await _api.getJson('/videos/$videoId');
    return VideoDetail.fromJson(data);
  }

  /// 视频搜索：标题模糊 + 标签精确（游客可访问）。
  Future<PageData<Video>> searchVideos({
    required String keyword,
    required int pageNum,
  }) async {
    final data = await _api.getJson(
      '/search/videos',
      query: {'keyword': keyword, 'pageNum': pageNum},
    );
    return PageData.parse(
      data,
      parseItem: _parseSearchItem,
      pageNum: pageNum,
      pageSize: _pageSize,
    );
  }

  /// 搜索结果条目：一般为 video 对象，兼容 `{video:{...}, author:{...}}` 包裹形态。
  static Video _parseSearchItem(Map<String, dynamic> json) {
    final inner = json['video'];
    if (inner is Map<String, dynamic>) {
      return Video.fromJson(inner);
    }
    return Video.fromJson(json);
  }
}

/// 标签聚合页数据（预留）。
class TagPage {
  const TagPage({required this.name, required this.videos});
  final String name;
  final PageData<Video> videos;
}

/// 用户公开资料兜底解析：
/// `GET /users/{id}` 的响应可能是 `{user:{...}}` 包裹，也可能是用户对象本身。
User parseUserResponse(Map<String, dynamic> data) {
  final inner = data['user'];
  if (inner is Map<String, dynamic>) return User.fromJson(inner);
  return User.fromJson(data);
}
