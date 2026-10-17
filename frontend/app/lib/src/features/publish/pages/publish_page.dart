import 'dart:async' show Completer, StreamSubscription, unawaited;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:media_kit/media_kit.dart' show Media, Player;
import 'package:media_kit_video/media_kit_video.dart'
    show Video, VideoController, VideoState;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart'
    show AppRoutePath, RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/features/common/services/tag_service.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';
import 'package:shortplay_app/src/features/publish/services/draft_service.dart';
import 'package:shortplay_app/src/features/publish/services/upload_service.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 发布页：选/拍视频 → 填标题/简介/标签 → 分片上传（进度）→ 提交或存草稿
class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage>
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  final PublishService _publishService = PublishService();
  final TagService _tagService = TagService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagInputController = TextEditingController();

  File? _videoFile;

  /// 本地预览播放器（media_kit，与 feed 播放同一内核）
  Player? _previewPlayer;
  VideoController? _previewController;
  int? _videoDurationMs;
  int _previewWidth = 720;
  int _previewHeight = 1280;

  final List<String> _tags = [];

  bool _asDraft = false;
  bool _uploading = false;
  int _uploadPercent = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!GetIt.instance<UserAuthCache>().hasLogin) {
      // 发布需登录：进页面即引导（游客可浏览不可发布）
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final ok = await _ensureLoginOrExit();
        if (!ok && mounted) context.go(AppRoutePath.initial);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    unawaited(_previewPlayer?.dispose());
    super.dispose();
  }

  Future<bool> _ensureLoginOrExit() async {
    if (GetIt.instance<UserAuthCache>().hasLogin) return true;
    final loc = S.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.guestInteractionTitle),
        content: Text(loc.guestInteractionDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.goLogin),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await context.pushNamed(RouteNames.login);
    }
    return GetIt.instance<UserAuthCache>().hasLogin;
  }

  // ─── 选择/拍摄视频 ───────────────────────────────────

  Future<void> _pickVideo(ImageSource source) async {
    final loc = S.of(context);
    try {
      final xfile = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
      if (xfile == null) return;

      final player = Player();
      var durationMs = 0;
      int? width;
      int? height;

      // 等待媒体就绪，取时长与分辨率
      final ready = Completer<void>();
      late final StreamSubscription<Duration> sub;
      sub = player.stream.duration.listen((duration) {
        if (duration > Duration.zero && !ready.isCompleted) {
          durationMs = duration.inMilliseconds;
          width = player.state.width;
          height = player.state.height;
          ready.complete();
        }
      });
      await player.open(Media(xfile.path), play: false);
      await ready.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      unawaited(sub.cancel());

      _clearVideo();
      if (!mounted) {
        unawaited(player.dispose());
        return;
      }
      setState(() {
        _videoFile = File(xfile.path);
        _previewPlayer = player;
        _previewController = VideoController(player);
        _videoDurationMs = durationMs;
        _previewWidth = width ?? 720;
        _previewHeight = height ?? 1280;
      });
    } catch (_) {
      EasyLoading.showToast(loc.errorDefault);
    }
  }

  void _clearVideo() {
    final player = _previewPlayer;
    _previewPlayer = null;
    _previewController = null;
    _videoFile = null;
    _videoDurationMs = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    if (mounted) setState(() {});
  }

  // ─── 标签 ────────────────────────────────────────────

  void _addTag(String raw) {
    var tag = raw.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1);
    }
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  Future<void> _showTagPicker() async {
    final loc = S.of(context);
    final theme = Theme.of(context);

    // 拉取标签联想（失败静默，允许手动输入任意标签）
    List<String> suggestions = [];
    try {
      final page = await _tagService.list(
        const PaginationQuery(pageNum: 1, pageSize: 30),
      );
      suggestions = page.items.map((t) => t.name).toList();
    } catch (_) {
      suggestions = [];
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final keyword = _tagInputController.text.trim().toLowerCase();
            final filtered = keyword.isEmpty
                ? suggestions
                : suggestions
                    .where((tag) => tag.toLowerCase().contains(keyword))
                    .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.tagPickerTitle,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _tagInputController,
                      decoration: InputDecoration(
                        hintText: loc.tagInputHint,
                        prefixIcon: const Icon(Icons.tag),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) => setSheetState(() {}),
                      onSubmitted: (value) {
                        Navigator.of(sheetContext).pop();
                        _addTag(value);
                      },
                    ),
                    SizedBox(height: 12.h),
                    if (filtered.isNotEmpty)
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: filtered.map((tag) {
                          return ActionChip(
                            label: Text(tag),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _addTag(tag);
                            },
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        loc.noTagFound,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.colorScheme.onSurface.withAlpha(130),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── 上传与提交 ─────────────────────────────────────

  Future<void> _submit({required bool asDraft}) async {
    final loc = S.of(context);
    if (_videoFile == null) {
      EasyLoading.showToast(loc.pickVideoFirst);
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      EasyLoading.showToast(loc.titleRequired);
      return;
    }
    if (!GetIt.instance<UserAuthCache>().hasLogin) {
      final ok = await _ensureLoginOrExit();
      if (!ok) return;
    }

    setState(() {
      _uploading = true;
      _uploadPercent = 0;
      _asDraft = asDraft;
    });
    EasyLoading.show(
      status: loc.uploadingPercent(0),
      dismissOnTap: false,
      maskType: EasyLoadingMaskType.clear,
    );

    try {
      final task = await _publishService.uploadFile(
        file: _videoFile!,
        title: title,
        description: _descriptionController.text.trim(),
        tags: _tags,
        asDraft: asDraft,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadPercent = progress.percent);
          EasyLoading.showProgress(
            progress.percent / 100,
            status: loc.uploadingPercent(progress.percent),
          );
        },
      );

      EasyLoading.dismiss();
      if (!mounted) return;

      if (asDraft || task.status == UploadTaskStatus.merging) {
        // 合并抽帧由后端继续处理
        EasyLoading.showToast(loc.mergingVideo);
      }
      if (asDraft) {
        EasyLoading.showToast(loc.draftSaved);
      } else {
        EasyLoading.showToast(loc.publishSuccess);
      }

      // 重置表单
      _clearVideo();
      _titleController.clear();
      _descriptionController.clear();
      setState(() => _tags.clear());
    } on ApiStatusException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showToast(_uploadErrorMessage(e, loc));
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showToast(loc.publishFailed);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _uploadErrorMessage(ApiStatusException e, S loc) {
    switch (e.status.getReason) {
      case 'FILE_TOO_LARGE':
        return loc.errorPayloadTooLarge;
      case 'FILE_TYPE_NOT_ALLOWED':
        return loc.errorUnsupportedMediaType;
      default:
        return loc.publishFailed;
    }
  }

  // ─── 草稿箱 ─────────────────────────────────────────

  Future<void> _showDrafts() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return const _DraftsSheet();
      },
    );
  }

  // ─── UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.publish),
        actions: [
          TextButton.icon(
            onPressed: _showDrafts,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text(loc.drafts),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频预览 / 选择
            _buildVideoPicker(theme, loc),
            SizedBox(height: 16.h),
            // 标题
            Text(loc.titleLabel,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withAlpha(180))),
            SizedBox(height: 6.h),
            TextField(
              controller: _titleController,
              maxLength: 50,
              style: TextStyle(fontSize: 15.sp),
              decoration: InputDecoration(
                hintText: loc.titleHint,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                isDense: true,
              ),
            ),
            SizedBox(height: 12.h),
            // 简介
            Text(loc.descriptionLabel,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withAlpha(180))),
            SizedBox(height: 6.h),
            TextField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: loc.descriptionHint,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                isDense: true,
              ),
            ),
            SizedBox(height: 12.h),
            // 标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.addTags,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withAlpha(180))),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _showTagPicker,
                ),
              ],
            ),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _tags
                  .map((tag) => InputChip(
                        label: Text('#$tag'),
                        onDeleted: () =>
                            setState(() => _tags.remove(tag)),
                      ))
                  .toList(),
            ),
            SizedBox(height: 24.h),
            // 存草稿选项
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _asDraft,
              onChanged: _uploading
                  ? null
                  : (value) => setState(() => _asDraft = value),
              title: Text(loc.asDraftOption, style: TextStyle(fontSize: 14.sp)),
            ),
            // 提交按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _uploading ? null : () => _submit(asDraft: true),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(loc.saveDraft),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed:
                        _uploading ? null : () => _submit(asDraft: false),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      _uploading
                          ? loc.uploadingPercent(_uploadPercent)
                          : loc.submitPublish,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPicker(ThemeData theme, S loc) {
    final controller = _previewController;
    if (controller != null && _videoFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: AspectRatio(
              aspectRatio: _previewWidth / _previewHeight,
              child: Video(
                controller: controller,
                fit: BoxFit.contain,
                controls: (VideoState state) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: 8.h,
            right: 8.w,
            child: GestureDetector(
              onTap: _clearVideo,
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 18.r, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${_videoDurationMs == null ? 0 : (_videoDurationMs! / 1000).round()}s',
                style: TextStyle(fontSize: 11.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _PickerCard(
            icon: Icons.photo_library_outlined,
            label: loc.pickVideo,
            onTap: () => _pickVideo(ImageSource.gallery),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _PickerCard(
            icon: Icons.videocam_outlined,
            label: loc.recordVideo,
            onTap: () => _pickVideo(ImageSource.camera),
          ),
        ),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        height: 100.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(60),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30.sp, color: theme.colorScheme.primary),
            SizedBox(height: 8.h),
            Text(label, style: TextStyle(fontSize: 13.sp)),
          ],
        ),
      ),
    );
  }
}

/// 草稿箱面板：列表 / 提交 / 删除
class _DraftsSheet extends StatefulWidget {
  const _DraftsSheet();

  @override
  State<_DraftsSheet> createState() => _DraftsSheetState();
}

class _DraftsSheetState extends State<_DraftsSheet> {
  final DraftService _draftService = DraftService();
  List<VideoDraft> _drafts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _draftService.list();
      if (!mounted) return;
      setState(() {
        _drafts = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit(VideoDraft draft) async {
    final loc = S.of(context);
    try {
      await _draftService.submit(draft.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      EasyLoading.showToast(loc.publishSuccess);
    } on ApiStatusException catch (e) {
      EasyLoading.showToast(e.status.message ?? loc.errorDefault);
    } catch (_) {
      EasyLoading.showToast(loc.errorDefault);
    }
  }

  Future<void> _delete(VideoDraft draft) async {
    try {
      await _draftService.delete(draft.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      EasyLoading.showToast(S.of(context).errorDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            Text(
              loc.drafts,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: EdgeInsets.all(24.h),
                child: Center(child: Text(_error!)),
              )
            else if (_drafts.isEmpty)
              Padding(
                padding: EdgeInsets.all(24.h),
                child: Center(
                  child: Text(
                    loc.noWorksYet,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _drafts.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CoverImage(
                        url: draft.coverDisplayUrl,
                        width: 56.w,
                        height: 56.w,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      title: Text(
                        draft.title.isEmpty ? loc.drafts : draft.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      subtitle: Text(
                        '${draft.duration}s · ${draft.tags.map((t) => '#$t').join(' ')}',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.upload_outlined),
                            tooltip: loc.submitPublish,
                            onPressed: () => _submit(draft),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () => _delete(draft),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
