import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../blocs/publish_cubit.dart';
import '../../widgets/common.dart';
import '../login/login_page.dart';

/// 发布流程：底部「+」进入。
///
/// 选片（相册/拍摄）→ 预览 + 填写标题/简介/标签 → 分片上传 → 提交。
class PublishPage extends StatelessWidget {
  const PublishPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublishCubit>(
      create: (_) => PublishCubit(),
      child: const _PublishView(),
    );
  }
}

class _PublishView extends StatefulWidget {
  const _PublishView();

  @override
  State<_PublishView> createState() => _PublishViewState();
}

class _PublishViewState extends State<_PublishView> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool asDraft) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, '请填写标题');
      return;
    }
    final cubit = context.read<PublishCubit>();
    final tags = _tagsCtrl.text
        .split(RegExp('[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final ok = await cubit.submit(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      tags: tags,
      asDraft: asDraft,
    );
    if (!mounted) return;
    if (ok) {
      showToast(
        context,
        asDraft ? '已保存为草稿' : '已提交，作品可能进入审核队列，请耐心等待',
      );
      Navigator.of(context).pop();
    } else {
      showToast(context, cubit.state.error ?? '提交失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发布')),
      body: BlocConsumer<PublishCubit, PublishState>(
        listener: (context, state) {},
        builder: (context, state) {
          switch (state.phase) {
            case PublishPhase.idle:
              return _buildPicker(context, state);
            case PublishPhase.ready:
            case PublishPhase.uploading:
            case PublishPhase.failed:
              return _buildForm(context, state);
            case PublishPhase.success:
              return const Center(child: Text('已提交'));
          }
        },
      ),
    );
  }

  /// 选片：拍摄 / 相册。
  Widget _buildPicker(BuildContext context, PublishState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PickerCard(
            icon: Icons.photo_camera_outlined,
            title: '拍摄视频',
            subtitle: '使用相机拍摄一段短视频',
            onTap: () => context.read<PublishCubit>().pickFromCamera(),
          ),
          const SizedBox(height: 20),
          _PickerCard(
            icon: Icons.photo_library_outlined,
            title: '从相册选择',
            subtitle: '选择已录制好的视频上传',
            onTap: () => context.read<PublishCubit>().pickFromGallery(),
          ),
        ],
      ),
    );
  }

  /// 预览 + 表单。
  Widget _buildForm(BuildContext context, PublishState state) {
    final uploading = state.phase == PublishPhase.uploading;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: state.width > 0 && state.height > 0
                ? state.width / state.height
                : 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PreviewPlayer(
                file: state.file!,
                onMeta: (duration, width, height) =>
                    context.read<PublishCubit>().updateMeta(
                          durationSeconds: duration,
                          width: width,
                          height: height,
                        ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            enabled: !uploading,
            maxLength: 50,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '标题（必填）',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            enabled: !uploading,
            maxLength: 200,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '简介（选填）',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsCtrl,
            enabled: !uploading,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '标签，逗号分隔（如：搞笑,生活）',
            ),
          ),
          const SizedBox(height: 16),
          if (uploading) ...[
            LinearProgressIndicator(
              value: state.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(
              '上传中 ${state.uploadedChunks}/${state.totalChunks} 分片'
              '（${(state.progress * 100).toStringAsFixed(0)}%）',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              state.error ?? '发布后作品将进入审核流程',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: state.error != null
                    ? Colors.redAccent
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      uploading ? null : () => _submit(true),
                  child: const Text('存草稿'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: uploading ? null : () => _submit(false),
                  child: Text(uploading ? '上传中…' : '发布'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 选片入口卡片。
class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.white70),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 本地视频预览播放器：顺带探测时长 / 宽高，回传给发布表单。
class _PreviewPlayer extends StatefulWidget {
  const _PreviewPlayer({required this.file, required this.onMeta});

  final File file;
  final void Function(int durationSeconds, int width, int height) onMeta;

  @override
  State<_PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<_PreviewPlayer> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  bool _metaSent = false;

  int _durationSeconds = 0;
  int _width = 0;
  int _height = 0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.file.path));
    _durationSub = _player.stream.duration.listen(_onMeta);
    _widthSub = _player.stream.width.listen(_onMeta);
    _heightSub = _player.stream.height.listen(_onMeta);
  }

  void _onMeta([Object? _]) {
    if (!mounted) return;
    setState(() {
      _durationSeconds =
          _player.state.duration.inSeconds;
      _width = _player.state.width ?? 0;
      _height = _player.state.height ?? 0;
    });
    if (!_metaSent &&
        _durationSeconds > 0 &&
        _width > 0 &&
        _height > 0) {
      _metaSent = true;
      widget.onMeta(_durationSeconds, _width, _height);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _width > 0 ? _width.toDouble() : 360,
        height: _height > 0 ? _height.toDouble() : 640,
        child: Video(
          controller: _controller,
          controls: (state) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
