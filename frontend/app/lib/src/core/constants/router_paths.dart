/// 应用路由的路径定义
class AppRoutePath {
  AppRoutePath._(); // Private constructor to prevent instantiation

  /// 首页（沉浸式 Feed）
  static const initial = '/';

  /// 登录
  static const login = '/login';

  /// 搜索
  static const search = '/search';

  /// 发布
  static const publish = '/publish';

  /// 消息通知
  static const notify = '/notify';

  /// 我的
  static const profile = '/profile';

  /// 单视频沉浸页（Feed 点击更多 / 搜索结果 / 通知跳转）
  static const videoDetail = '/video/:videoId';

  /// 他人主页
  static const userProfile = '/user/:userId';

  /// 剧集详情
  static const seriesDetail = '/series/:seriesId';

  /// 热榜
  static const hotList = '/hot';

  /// 创作者数据（近 N 日趋势）
  static const creatorStats = '/creator/stats';

  /// 视频详情路径模板（跳转用：`AppRoutePath.videoPath(1)`）
  static String videoPath(int videoId) => '/video/$videoId';

  /// 剧集详情路径模板（跳转用：`AppRoutePath.seriesPath(1)`）
  static String seriesPath(int seriesId) => '/series/$seriesId';

  /// 他人主页路径模板
  static String userPath(int userId) => '/user/$userId';

  /// 系统设置
  static const settings = '/settings';

  /// 未找到
  static const notFound = '/not_found';
}
