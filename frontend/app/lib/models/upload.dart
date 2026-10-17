import 'common.dart';

/// 分片上传任务（POST /uploads 等）。
///
/// 文档中该对象字段写作 task_id/chunk_size/total_chunks（snake_case），
/// 与全站 camelCase 约定不一致，这里做双格式兼容解析。
class UploadTask {
  const UploadTask({
    required this.taskId,
    this.chunkSize = 0,
    this.totalChunks = 0,
    this.uploadedChunks = const [],
  });

  final String taskId;
  final int chunkSize;
  final int totalChunks;
  final List<int> uploadedChunks;

  factory UploadTask.fromJson(Map<String, dynamic> json) {
    final rawId =
        json['taskId'] ?? json['task_id'] ?? json['id'] ?? json['ID'];
    return UploadTask(
      taskId: asStr(rawId),
      chunkSize: asInt(json['chunkSize'] ?? json['chunk_size']),
      totalChunks: asInt(json['totalChunks'] ?? json['total_chunks']),
      uploadedChunks: _parseInts(
        json['uploadedChunks'] ?? json['uploaded_chunks'],
      ),
    );
  }

  static List<int> _parseInts(Object? raw) {
    if (raw is List) {
      return raw.map((e) => asInt(e)).toList();
    }
    return const [];
  }
}
