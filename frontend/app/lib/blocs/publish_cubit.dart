import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../services/services.dart';

/// 发布流程阶段。
enum PublishPhase { idle, ready, uploading, success, failed }

/// 发布状态。
class PublishState extends Equatable {
  const PublishState({
    this.phase = PublishPhase.idle,
    this.file,
    this.durationSeconds = 0,
    this.width = 0,
    this.height = 0,
    this.uploadedChunks = 0,
    this.totalChunks = 0,
    this.error,
  });

  final PublishPhase phase;
  final File? file;

  /// 预览播放器探测到的视频元信息。
  final int durationSeconds;
  final int width;
  final int height;

  final int uploadedChunks;
  final int totalChunks;
  final String? error;

  /// 上传进度（0~1），按已完成分片数计算。
  double get progress =>
      totalChunks > 0 ? (uploadedChunks / totalChunks).clamp(0.0, 1.0) : 0;

  PublishState copyWith({
    PublishPhase? phase,
    File? file,
    bool clearFile = false,
    int? durationSeconds,
    int? width,
    int? height,
    int? uploadedChunks,
    int? totalChunks,
    String? error,
    bool clearError = false,
  }) {
    return PublishState(
      phase: phase ?? this.phase,
      file: clearFile ? null : (file ?? this.file),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      uploadedChunks: uploadedChunks ?? this.uploadedChunks,
      totalChunks: totalChunks ?? this.totalChunks,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        phase, file, durationSeconds, width, height,
        uploadedChunks, totalChunks, error,
      ];
}

/// 发布域 Cubit：选片 → 填表 → 分片上传 → complete。
class PublishCubit extends Cubit<PublishState> {
  PublishCubit() : super(const PublishState());

  final ImagePicker _picker = ImagePicker();

  /// 从相册选择视频。
  Future<void> pickFromGallery() => _pick(ImageSource.gallery);

  /// 拍摄视频。
  Future<void> pickFromCamera() => _pick(ImageSource.camera);

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickVideo(source: source);
      if (x == null) return;
      emit(
        PublishState(
          phase: PublishPhase.ready,
          file: File(x.path),
        ),
      );
    } catch (e) {
      emit(const PublishState(phase: PublishPhase.idle));
    }
  }

  /// 记录预览播放器探测到的元信息。
  void updateMeta({
    int? durationSeconds,
    int? width,
    int? height,
  }) {
    emit(
      state.copyWith(
        durationSeconds: durationSeconds,
        width: width,
        height: height,
      ),
    );
  }

  /// 执行分片上传并提交。
  ///
  /// [asDraft]=true 时 complete 传 asDraft，存为草稿。
  /// 返回 true 表示提交成功。
  Future<bool> submit({
    required String title,
    String? description,
    List<String> tags = const [],
    bool asDraft = false,
  }) async {
    final file = state.file;
    if (file == null || !file.existsSync()) {
      emit(state.copyWith(phase: PublishPhase.failed, error: '请先选择视频'));
      return false;
    }
    emit(
      state.copyWith(
        phase: PublishPhase.uploading,
        clearError: true,
        uploadedChunks: 0,
        totalChunks: 0,
      ),
    );
    try {
      final size = file.lengthSync();
      final task =
          await Services.upload.createTask(file.uri.pathSegments.last, size);
      final total = task.totalChunks > 0
          ? task.totalChunks
          : (task.chunkSize > 0 ? (size / task.chunkSize).ceil() : 1);
      final chunkSize = task.chunkSize > 0 ? task.chunkSize : size;
      emit(state.copyWith(totalChunks: total));

      for (var i = 0; i < total; i++) {
        final offset = i * chunkSize;
        final end = (offset + chunkSize > size) ? size : offset + chunkSize;
        if (offset >= size) break;
        final bytes = UploadService.readChunk(file, offset, end - offset);
        await Services.upload.uploadChunk(task.taskId, i, bytes);
        emit(state.copyWith(uploadedChunks: i + 1));
      }

      await Services.upload.complete(
        task.taskId,
        title: title,
        description: description,
        tags: tags,
        duration: state.durationSeconds,
        width: state.width,
        height: state.height,
        asDraft: asDraft,
      );
      emit(state.copyWith(phase: PublishPhase.success));
      return true;
    } on ApiException catch (e) {
      var msg = e.message;
      if (e.isReason('FILE_TOO_LARGE')) msg = '视频过大，超出服务端限制';
      if (e.isReason('FILE_TYPE_NOT_ALLOWED')) msg = '不支持的视频格式';
      emit(state.copyWith(phase: PublishPhase.failed, error: msg));
      return false;
    }
  }

  /// 清空回到初始（放弃当前选择）。
  void reset() => emit(const PublishState());
}
