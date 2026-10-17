/// RPC返回状态
class Status {
  final int? code;
  final String? reason;
  final String? message;
  final Map<String, String>? metadata;

  String get getMessage => message ?? '';

  String get getReason => reason ?? '';

  Status({
    this.code,
    this.reason,
    this.message,
    this.metadata,
  });

  Status.fromJson(Map<String, dynamic> json)
      : code = (json['code'] != null) ? json['code'] : null,
        reason = (json['reason'] != null) ? json['reason'] : null,
        message = (json['message'] != null) ? json['message'] : null,
        metadata =
            (json['metadata'] != null) ? Map.from(json['metadata']) : null;
}

/// 携带后端错误 Status 的异常
///
/// service 层把 DioException 统一转换为 [Status] 后抛出，
/// UI 层捕获后用 `localizedApiErrorMessage` 转本地化文案。
class ApiStatusException implements Exception {
  final Status status;

  ApiStatusException(this.status);

  @override
  String toString() => 'ApiStatusException(${status.getReason}: ${status.message})';
}
