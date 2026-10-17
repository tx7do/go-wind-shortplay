import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/services/base_service.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/convert.dart';

/// 上传任务状态（protojson 枚举全名）
class UploadTaskStatus {
  UploadTaskStatus._();

  static const uploading = 'UPLOAD_TASK_STATUS_UPLOADING';
  static const merging = 'UPLOAD_TASK_STATUS_MERGING';
  static const completed = 'UPLOAD_TASK_STATUS_COMPLETED';
  static const failed = 'UPLOAD_TASK_STATUS_FAILED';
}

/// 上传任务（video.service.v1.UploadTask）
class UploadTask {
  final String taskId;
  final String fileName;

  /// 文件大小（int64 → 字符串）
  final int fileSize;

  /// 分片大小（uint32 → 数字）
  final int chunkSize;
  final int totalChunks;
  final String status;
  final int videoId;

  const UploadTask({
    required this.taskId,
    this.fileName = '',
    this.fileSize = 0,
    this.chunkSize = 0,
    this.totalChunks = 0,
    this.status = UploadTaskStatus.uploading,
    this.videoId = 0,
  });

  factory UploadTask.fromJson(Map<String, dynamic> json) {
    return UploadTask(
      taskId: jsonString(json['taskId']),
      fileName: jsonString(json['fileName']),
      fileSize: jsonInt(json['fileSize']),
      chunkSize: jsonInt(json['chunkSize']),
      totalChunks: jsonInt(json['totalChunks']),
      status: jsonString(json['status'], fallback: UploadTaskStatus.uploading),
      videoId: jsonInt(json['videoId']),
    );
  }
}

/// 上传进度
class UploadProgress {
  final int uploadedChunks;
  final int totalChunks;

  const UploadProgress({required this.uploadedChunks, required this.totalChunks});

  int get percent =>
      totalChunks <= 0 ? 0 : (uploadedChunks * 100 / totalChunks).round();
}

/// 创作发布服务：分片上传 / 合并提交 / 草稿
///
/// 分片上传协议（后端已实测）：
/// 1. POST /uploads {fileName,fileSize,chunkSize?} → {taskId,chunkSize,totalChunks}
/// 2. PUT /uploads/{taskId}/chunks/{i}（body = 分片原始字节，octet-stream）
/// 3. POST /uploads/{taskId}/complete {title,description?,tags[],asDraft?}
class PublishService extends BaseService {
  PublishService() : super(tag: 'PublishService');

  /// 上传用独立 Dio：不走全局认证外的拦截器配置，且放宽超时
  Dio get _dio {
    final global = GetIt.instance<Dio>();
    return Dio(BaseOptions(
      baseUrl: global.options.baseUrl,
      connectTimeout: global.options.connectTimeout,
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      responseType: ResponseType.json,
    ));
  }

  /// 创建上传任务
  Future<UploadTask> createTask({
    required String fileName,
    required int fileSize,
    int? chunkSize,
  }) async {
    try {
      // protojson：fileSize 为 int64 → 字符串
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads',
        data: {
          'fileName': fileName,
          'fileSize': '$fileSize',
          'chunkSize': ?chunkSize,
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return UploadTask.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 上传单个分片（body = 原始字节）
  Future<List<int>> uploadChunk({
    required String taskId,
    required int chunkIndex,
    required List<int> bytes,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/uploads/$taskId/chunks/$chunkIndex',
        data: Stream.fromIterable([bytes]),
        options: Options(
          contentType: 'application/octet-stream',
          headers: {'Content-Length': '${bytes.length}'},
        ),
      );
      final uploaded = res.data?['uploadedChunks'];
      if (uploaded is List) {
        return uploaded.whereType<num>().map((e) => e.toInt()).toList();
      }
      return [chunkIndex];
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 分片顺序上传整个文件（带进度回调）
  Future<UploadTask> uploadFile({
    required File file,
    required String title,
    String description = '',
    List<String> tags = const [],
    bool asDraft = false,
    void Function(UploadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final size = file.lengthSync();
    final task = await createTask(
      fileName: file.uri.pathSegments.last,
      fileSize: size,
    );

    final raf = file.openSync();
    try {
      for (var i = 0; i < task.totalChunks; i++) {
        final start = i * task.chunkSize;
        final end = (start + task.chunkSize).clamp(0, size);
        raf.setPositionSync(start);
        final bytes = raf.readSync(end - start);

        await uploadChunk(
          taskId: task.taskId,
          chunkIndex: i,
          bytes: bytes,
        );
        onProgress?.call(UploadProgress(
          uploadedChunks: i + 1,
          totalChunks: task.totalChunks,
        ));
      }
    } finally {
      raf.closeSync();
    }

    return completeTask(
      taskId: task.taskId,
      title: title,
      description: description,
      tags: tags,
      asDraft: asDraft,
      cancelToken: cancelToken,
    );
  }

  /// 合并完成（提交发布或存草稿）
  Future<UploadTask> completeTask({
    required String taskId,
    required String title,
    String description = '',
    List<String> tags = const [],
    bool asDraft = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/$taskId/complete',
        data: {
          'title': title,
          if (description.isNotEmpty) 'description': description,
          'tags': tags,
          'asDraft': asDraft,
        },
        cancelToken: cancelToken,
      );
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return UploadTask.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }

  /// 查询任务状态
  Future<UploadTask> getTask(String taskId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/uploads/$taskId');
      final data = res.data;
      if (data == null) {
        throw ApiStatusException(Status(message: 'empty response'));
      }
      return UploadTask.fromJson(data);
    } on DioException catch (e) {
      throw ApiStatusException(handleDioError(e));
    }
  }
}
