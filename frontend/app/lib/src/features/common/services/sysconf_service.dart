import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';

/// 系统配置（sysconf.service.v1.SysConf 的 App 消费子集）
class SysConf {
  /// App 公告横幅开关
  final bool announcementEnabled;

  /// 公告文案（空则不展示）
  final String announcementText;

  /// 公告跳转链接（可空）
  final String announcementLink;

  const SysConf({
    this.announcementEnabled = false,
    this.announcementText = '',
    this.announcementLink = '',
  });

  factory SysConf.fromJson(Map<String, dynamic> json) {
    return SysConf(
      announcementEnabled: jsonBool(json['announcementEnabled']),
      announcementText: jsonString(json['announcementText']),
      announcementLink: jsonString(json['announcementLink']),
    );
  }

  /// 公告横幅是否可见
  bool get announcementVisible =>
      announcementEnabled && announcementText.trim().isNotEmpty;
}

/// 系统配置服务（GET /sysconf，游客可访问；失败静默返回默认值）
class SysConfService extends BaseService {
  SysConfService() : super(tag: 'SysConfService');

  Dio get _dio => GetIt.instance<Dio>();

  /// 拉取系统配置（尽力而为：网络/接口失败回退默认配置，不阻塞启动）
  Future<SysConf> getSysConf() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/sysconf');
      return SysConf.fromJson(res.data ?? const {});
    } on DioException {
      return const SysConf();
    }
  }
}
