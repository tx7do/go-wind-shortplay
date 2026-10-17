import '../core/network/api_client.dart';
import '../models/common.dart';
import '../models/user.dart';
import '../models/video.dart';
import 'feed_service.dart';

/// 用户资料 / 统计 / 作品 / 创作者中心。
class UserService {
  UserService(this._api);

  final ApiClient _api;

  /// 用户公开资料（游客可访问）。
  Future<User> user(int userId) async {
    final data = await _api.getJson('/users/$userId');
    return parseUserResponse(data);
  }

  /// 用户统计（游客可访问）。
  Future<UserStats> stats(int userId) async {
    final data = await _api.getJson('/users/$userId/stats');
    return UserStats.fromJson(data);
  }

  /// 用户作品列表（本人含审核中/驳回/下架，他人仅已发布）。
  Future<PageData<Video>> userVideos({
    required int userId,
    required int pageNum,
  }) async {
    final data = await _api.getJson(
      '/users/$userId/videos',
      query: {'pageNum': pageNum},
    );
    return PageData.parse(
      data,
      parseItem: UserService._parseVideoItem,
      pageNum: pageNum,
      pageSize: 10,
    );
  }

  /// 编辑本人资料（PUT /profile，id 取令牌）。
  ///
  /// 空字符串与 null 等价：不提交该字段。
  Future<User> updateProfile({
    String? nickname,
    String? bio,
    String? avatarUrl,
  }) async {
    final name = (nickname == null || nickname.isEmpty) ? null : nickname;
    final avatar = (avatarUrl == null || avatarUrl.isEmpty) ? null : avatarUrl;
    final data = await _api.putJson(
      '/profile',
      data: {
        'nickname': ?name,
        'bio': ?bio,
        'avatarUrl': ?avatar,
      },
    );
    return parseUserResponse(data);
  }

  /// 创作者中心汇总（GET /creator/overview）。
  Future<CreatorOverview> creatorOverview() async {
    final data = await _api.getJson('/creator/overview');
    return CreatorOverview.fromJson(data);
  }

  /// 作品列表条目一般为 video 对象，兼容包裹形态。
  static Video _parseVideoItem(Map<String, dynamic> json) {
    final inner = json['video'];
    if (inner is Map<String, dynamic>) return Video.fromJson(inner);
    return Video.fromJson(json);
  }
}
