import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import 'auth_service.dart';
import 'comment_service.dart';
import 'feed_service.dart';
import 'interaction_service.dart';
import 'notification_service.dart';
import 'report_service.dart';
import 'uba_service.dart';
import 'upload_service.dart';
import 'user_service.dart';

// 常用类型随服务一起导出，调用方无需重复 import。
export '../core/network/api_exception.dart' show ApiException;
export 'report_service.dart' show ReportService;
export 'uba_service.dart' show UbaEvent, UbaEventType;
export 'upload_service.dart' show UploadService;

/// 轻量服务定位器：main() 中初始化一次，各页面直接读取静态字段。
class Services {
  Services._();

  static late final ApiClient api;
  static late final TokenStore tokens;
  static late final AuthService auth;
  static late final FeedService feed;
  static late final InteractionService interaction;
  static late final CommentService comment;
  static late final UploadService upload;
  static late final UserService user;
  static late final NotificationService notification;
  static late final ReportService report;
  static late final UbaService uba;

  static void init({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) {
    api = apiClient;
    tokens = tokenStore;
    auth = AuthService(apiClient);
    feed = FeedService(apiClient);
    interaction = InteractionService(apiClient);
    comment = CommentService(apiClient);
    upload = UploadService(apiClient);
    user = UserService(apiClient);
    notification = NotificationService(apiClient);
    report = ReportService(apiClient);
    uba = UbaService(apiClient);
  }
}
