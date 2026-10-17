import '../core/network/api_client.dart';
import '../models/common.dart';
import '../models/video.dart';

/// 互动接口：点赞 / 收藏 / 关注 / 观看者状态 / 我的收藏。
class InteractionService {
  InteractionService(this._api);

  final ApiClient _api;

  /// 点赞。targetType：1 视频 / 2 评论。返回 `{liked, likeCount}`（幂等）。
  Future<Map<String, dynamic>> like(int targetType, int targetId) =>
      _api.postJson('/likes', data: {'targetType': targetType, 'targetId': targetId});

  /// 取消点赞。
  Future<Map<String, dynamic>> unlike(int targetType, int targetId) =>
      _api.deleteJson('/likes/$targetType/$targetId');

  /// 收藏视频 → `{collected, collectCount}`。
  Future<Map<String, dynamic>> collect(int videoId) =>
      _api.postJson('/videos/$videoId/collect');

  /// 取消收藏。
  Future<Map<String, dynamic>> uncollect(int videoId) =>
      _api.deleteJson('/videos/$videoId/collect');

  /// 关注用户 → `{following}`；409 CANNOT_FOLLOW_SELF 由 UI 提示。
  Future<Map<String, dynamic>> follow(int userId) =>
      _api.postJson('/users/$userId/follow');

  /// 取消关注。
  Future<Map<String, dynamic>> unfollow(int userId) =>
      _api.deleteJson('/users/$userId/follow');

  /// 批量查询当前用户对视频的点赞/收藏状态（游客返回全 false）。
  Future<Map<int, ViewerState>> interactionStatus(List<int> videoIds) async {
    if (videoIds.isEmpty) return {};
    final data = await _api.postJson(
      '/interactions/status',
      data: {'videoIds': videoIds},
    );
    final statuses = data['statuses'];
    final result = <int, ViewerState>{};
    if (statuses is Map) {
      statuses.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null && value is Map<String, dynamic>) {
          result[id] = ViewerState.fromJson(value);
        }
      });
    }
    return result;
  }

  /// 我的收藏列表（注意：该接口分页参数为 `page`）。
  Future<PageData<Video>> collects({required int page}) async {
    final data = await _api.getJson('/collects', query: {'page': page});
    return PageData.parse(
      data,
      parseItem: _parseCollectItem,
      pageNum: page,
      pageSize: 10,
    );
  }

  /// 收藏列表条目一般为 video 对象，兼容包裹形态。
  static Video _parseCollectItem(Map<String, dynamic> json) {
    final inner = json['video'];
    if (inner is Map<String, dynamic>) return Video.fromJson(inner);
    return Video.fromJson(json);
  }
}
