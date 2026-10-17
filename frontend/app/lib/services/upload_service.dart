import 'dart:io';

import '../core/network/api_client.dart';
import '../models/upload.dart';

/// 分片上传服务。
///
/// 协议（见 docs/API.md）：
/// 1. `POST /uploads {fileName,fileSize}` → UploadTask（taskId/chunkSize/totalChunks）
/// 2. 循环 `PUT /uploads/{taskId}/chunks/{i}`，body 为分片原始字节
/// 3. `POST /uploads/{taskId}/complete {title,...}` 完成合并与抽帧
class UploadService {
  UploadService(this._api);

  final ApiClient _api;

  /// 创建上传任务（413 FILE_TOO_LARGE / 415 FILE_TYPE_NOT_ALLOWED 由 UI 提示）。
  Future<UploadTask> createTask(String fileName, int fileSize) async {
    final data = await _api.postJson(
      '/uploads',
      data: {'fileName': fileName, 'fileSize': fileSize},
    );
    return UploadTask.fromJson(data);
  }

  /// 上传第 [index] 个分片（从 0 开始计数与后端对齐）。
  Future<void> uploadChunk(String taskId, int index, List<int> bytes) =>
      _api.putBytes('/uploads/$taskId/chunks/$index', bytes);

  /// 通知服务端合并分片并发布（asDraft=true 存草稿）。
  Future<UploadTask> complete(
    String taskId, {
    required String title,
    String? description,
    List<String> tags = const [],
    int? duration,
    int? width,
    int? height,
    bool asDraft = false,
  }) async {
    final data = await _api.postJson(
      '/uploads/$taskId/complete',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'tags': tags,
        if (duration != null && duration > 0) 'duration': duration,
        if (width != null && width > 0) 'width': width,
        if (height != null && height > 0) 'height': height,
        'asDraft': asDraft,
      },
    );
    return UploadTask.fromJson(data);
  }

  /// 查询任务状态（预留）。
  Future<UploadTask> taskStatus(String taskId) async {
    final data = await _api.getJson('/uploads/$taskId');
    return UploadTask.fromJson(data);
  }

  /// 按分片读取本地文件字节。
  static List<int> readChunk(File file, int offset, int length) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      raf.setPositionSync(offset);
      return raf.readSync(length);
    } finally {
      raf.closeSync();
    }
  }
}
