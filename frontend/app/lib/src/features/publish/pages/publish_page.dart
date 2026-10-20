import 'dart:async' show Completer, StreamSubscription, unawaited;
import 'dart:io' show File;
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:media_kit/media_kit.dart'
    show Media, Player, PlayerConfiguration, PlaylistMode;
import 'package:media_kit_video/media_kit_video.dart'
    show Video, VideoController, VideoState;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart'
    show AppRoutePath, RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/services/pagination_query.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart';
import 'package:shortplay_app/src/core/utilities/platform.dart';
import 'package:shortplay_app/src/features/common/services/tag_service.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';
import 'package:shortplay_app/src/features/publish/services/draft_service.dart';
import 'package:shortplay_app/src/features/common/data/models.dart'
    show Series;
import 'package:shortplay_app/src/features/publish/services/upload_service.dart';
import 'package:shortplay_app/src/features/publish/widgets/series_picker_sheet.dart';
import 'package:get_it/get_it.dart' show GetIt;

/// 发布页（抖音风格重设计）：
/// - 未选视频：整页大区块引导（大图标 + 引导文案 + 双大按钮）
/// - 已选视频：9:16 播放预览卡（时长角标 / 重选 / 移除）+ 卡片式表单
///   （标题 x/50、简介 x/200、标签 Chip 流式、高级设置收纳存草稿开关）
///   + 底部固定双按钮（存草稿描边 / 发布实心带进度）
/// 逻辑（校验 / 分片上传进度 / 草稿箱）与重设计前一致。
class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage>
    with AutomaticKeepAliveClientMixin {
  static const int _titleMaxLength = 50;
  static const int _descriptionMaxLength = 200;

  final ImagePicker _picker = ImagePicker();
  final PublishService _publishService = PublishService();
  final TagService _tagService = TagService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagInputController = TextEditingController();

  File? _videoFile;

  /// 本地预览播放器（media_kit，与 feed 播放同一内核，循环静音预览）
  Player? _previewPlayer;
  VideoController? _previewController;
  int? _videoDurationMs;

  final List<String> _tags = [];

  // 挂靠剧集（null=不挂靠；发布后服务端自动排集号）
  Series? _attachedSeries;

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

      // 循环静音预览，自动播放
      final player = Player(
        configuration: const PlayerConfiguration(muted: true),
      );
      await player.setPlaylistMode(PlaylistMode.loop);
      var durationMs = 0;

      // 等待媒体就绪，取时长
      final ready = Completer<void>();
      late final StreamSubscription<Duration> sub;
      sub = player.stream.duration.listen((duration) {
        if (duration > Duration.zero && !ready.isCompleted) {
          durationMs = duration.inMilliseconds;
          ready.complete();
        }
      });
      await player.open(Media(xfile.path), play: true);
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

  String _formatDuration(int? ms) {
    final totalSeconds = ((ms ?? 0) / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ─── 标签 ────────────────────────────────────────────

  /// 尝试添加标签（去 # / 去重），返回是否真正新增
  bool _tryAddTag(String raw) {
    var tag = raw.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1);
    }
    if (tag.isEmpty || _tags.contains(tag)) return false;
    _tags.add(tag);
    return true;
  }

  void _addTag(String raw) {
    if (_tryAddTag(raw)) {
      _tagInputController.clear();
      setState(() {});
    }
  }

  /// 行内输入：回车或逗号（中英文）均可提交标签
  void _commitTagInput(String raw) {
    final parts = raw.split(RegExp('[,，]'));
    var added = false;
    for (final part in parts) {
      if (_tryAddTag(part)) added = true;
    }
    if (added) _tagInputController.clear();
    setState(() {});
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
      // 桌面宽窗下收窄居中（手机端无感）
      constraints: const BoxConstraints(maxWidth: 560),
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
        seriesId: _attachedSeries?.id,
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
      setState(() {
        _tags.clear();
        _attachedSeries = null;
      });
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
      case 'SENSITIVE_WORD_HIT':
        return loc.errorSensitiveWordHit;
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
      // 桌面宽窗下收窄居中（手机端无感）
      constraints: const BoxConstraints(maxWidth: 560),
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
    final hasVideo = _previewController != null && _videoFile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.publish),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: TextButton.icon(
              onPressed: _showDrafts,
              icon: Icon(Icons.inventory_2_outlined, size: 18.sp),
              label: Text(loc.drafts, style: TextStyle(fontSize: 13.sp)),
            ),
          ),
        ],
      ),
      body: hasVideo ? _buildEditorBody(loc) : _buildEmptyGuide(loc),
    );
  }

  /// 未选视频：整页大区块引导
  Widget _buildEmptyGuide(S loc) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 主视觉：品牌渐变大图标
            Container(
              width: 116.w,
              height: 116.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32.r),
                gradient: BrandColor.gradient,
                boxShadow: [
                  BoxShadow(
                    color: BrandColor.rose.withAlpha(70),
                    blurRadius: 32.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Icon(
                Icons.movie_filter_outlined,
                size: 60.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              loc.chooseVideoToCreate,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              loc.publishGuideSubtitle,
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurface.withAlpha(130),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 44.h),
            _GuideButton(
              icon: Icons.photo_library_outlined,
              label: loc.pickVideo,
              filled: true,
              onTap: () => _pickVideo(ImageSource.gallery),
            ),
            // 拍摄仅移动端提供（image_picker 桌面实现只支持文件选择）
            if (PlatformUtils.isMobile) ...[
              SizedBox(height: 14.h),
              _GuideButton(
                icon: Icons.videocam_outlined,
                label: loc.recordVideo,
                onTap: () => _pickVideo(ImageSource.camera),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 已选视频：滚动区（9:16 预览卡 + 表单卡）+ 底部固定操作栏
  Widget _buildEditorBody(S loc) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
                child: Column(
                  children: [
                    _buildPreviewCard(theme, loc),
                    SizedBox(height: 14.h),
                    _buildFieldCard(
                      theme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _titleController,
                            maxLength: _titleMaxLength,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration.collapsed(
                              hintText: loc.titleHint,
                              hintStyle: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  90,
                                ),
                              ),
                            ),
                            buildCounter: _hiddenCounter,
                          ),
                          SizedBox(height: 6.h),
                          _buildCounter(_titleController, _titleMaxLength),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildFieldCard(
                      theme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _descriptionController,
                            maxLength: _descriptionMaxLength,
                            maxLines: 3,
                            minLines: 2,
                            style: TextStyle(fontSize: 14.sp),
                            decoration: InputDecoration.collapsed(
                              hintText: loc.descriptionHint,
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  90,
                                ),
                              ),
                            ),
                            buildCounter: _hiddenCounter,
                          ),
                          SizedBox(height: 6.h),
                          _buildCounter(
                            _descriptionController,
                            _descriptionMaxLength,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildTagsCard(theme, loc),
                    SizedBox(height: 10.h),
                    _buildSeriesCard(theme, loc),
                    SizedBox(height: 10.h),
                    _buildAdvancedCard(theme, loc),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 底部固定操作栏（含底导航避让）
        _buildBottomActionBar(theme, loc),
      ],
    );
  }

  /// 9:16 视频预览卡：播放预览 + 时长角标 + 移除 / 重选
  Widget _buildPreviewCard(ThemeData theme, S loc) {
    final player = _previewPlayer!;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 卡片固定 9:16，高度不超过可视区 42%，宽度不超可用宽
        final maxHeight = MediaQuery.of(context).size.height * 0.42;
        final cardWidth = min(constraints.maxWidth, maxHeight * 9 / 16);
        final cardHeight = cardWidth * 16 / 9;
        return Center(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  color: Colors.black,
                  child: GestureDetector(
                    onTap: () => unawaited(player.playOrPause()),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Video(
                          controller: _previewController!,
                          fit: BoxFit.contain,
                          width: cardWidth,
                          height: cardHeight,
                          controls: (VideoState state) =>
                              const SizedBox.shrink(),
                        ),
                        // 暂停时显示播放按钮
                        StreamBuilder<bool>(
                          stream: player.stream.playing,
                          initialData: player.state.playing,
                          builder: (context, playing) {
                            if (playing.data ?? false) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 40.sp,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 左上：移除
              Positioned(
                top: 10.h,
                left: 10.w,
                child: _PreviewPillButton(
                  icon: Icons.close,
                  tooltip: loc.removeVideo,
                  onTap: _clearVideo,
                ),
              ),
              // 右上：重选
              Positioned(
                top: 10.h,
                right: 10.w,
                child: _PreviewPillButton(
                  icon: Icons.refresh,
                  label: loc.reselectVideo,
                  onTap: () => _pickVideo(ImageSource.gallery),
                ),
              ),
              // 左下：时长角标
              Positioned(
                bottom: 10.h,
                left: 10.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 12.sp, color: Colors.white),
                      SizedBox(width: 4.w),
                      Text(
                        _formatDuration(_videoDurationMs),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 隐藏 TextField 默认计数器（改用 [_buildCounter] 自绘）
  static Widget _hiddenCounter(
    BuildContext _, {
    int? currentLength,
    int? maxLength,
    bool? isFocused,
  }) => const SizedBox.shrink();

  /// 表单卡片容器
  Widget _buildFieldCard(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: child,
    );
  }

  /// 字数计数 x/N
  Widget _buildCounter(TextEditingController controller, int maxLength) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final over = controller.text.length > maxLength;
        return Text(
          '${controller.text.length}/$maxLength',
          style: TextStyle(
            fontSize: 11.sp,
            color: over
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withAlpha(90),
          ),
        );
      },
    );
  }

  /// 标签卡：行内输入（回车/逗号添加）+ 已选 Chip 流式 + 联想入口
  Widget _buildTagsCard(ThemeData theme, S loc) {
    return _buildFieldCard(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 15.sp,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                loc.addTags,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showTagPicker,
                icon: Icon(Icons.auto_awesome_outlined, size: 14.sp),
                label: Text(
                  loc.tagPickerTitle,
                  style: TextStyle(fontSize: 12.sp),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          TextField(
            controller: _tagInputController,
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: loc.tagInlineHint,
              hintStyle: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurface.withAlpha(90),
              ),
              prefixIcon: Icon(
                Icons.tag,
                size: 16.sp,
                color: theme.colorScheme.primary,
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 32.w,
                minHeight: 32.h,
              ),
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.onSurface.withAlpha(12),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _commitTagInput,
            onSubmitted: _commitTagInput,
          ),
          if (_tags.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _tags
                  .map(
                    (tag) => InputChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      label: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 高级设置卡：收纳「存为草稿」开关
  /// 挂靠剧集卡：选中剧名 + 更换/移除；点击进选剧弹层
  Widget _buildSeriesCard(ThemeData theme, S loc) {
    final series = _attachedSeries;
    return _buildFieldCard(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.movie_outlined,
                size: 15.sp,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                loc.attachSeries,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showSeriesPicker,
                icon: Icon(Icons.playlist_add_check_rounded, size: 14.sp),
                label: Text(
                  series == null ? loc.chooseSeries : loc.changeSeries,
                  style: TextStyle(fontSize: 12.sp),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
              ),
            ],
          ),
          if (series != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          loc.attachSeriesHint(series.publishedCount),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: theme.colorScheme.onSurface.withAlpha(110),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: loc.attachSeriesRemove,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.sp,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                    onPressed: () => setState(() => _attachedSeries = null),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Text(
                loc.attachSeriesNone,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withAlpha(100),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 选剧弹层：我的剧集分页列表 + 新建剧集
  Future<void> _showSeriesPicker() async {
    if (!GetIt.instance<UserAuthCache>().hasLogin) {
      final ok = await _ensureLoginOrExit();
      if (!ok || !mounted) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) {
        return SeriesPickerSheet(
          selectedId: _attachedSeries?.id ?? 0,
          onSelected: (series) {
            if (!mounted) return;
            setState(() => _attachedSeries = series);
          },
        );
      },
    );
  }

  Widget _buildAdvancedCard(ThemeData theme, S loc) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w),
          childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
          collapsedShape: const Border(),
          shape: const Border(),
          iconColor: theme.colorScheme.onSurface.withAlpha(150),
          collapsedIconColor: theme.colorScheme.onSurface.withAlpha(150),
          title: Text(
            loc.advancedSettings,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: _asDraft,
              onChanged: _uploading
                  ? null
                  : (value) => setState(() => _asDraft = value),
              title: Text(
                loc.asDraftOption,
                style: TextStyle(fontSize: 13.5.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部固定操作栏：存草稿（描边）+ 发布（实心，上传中显示进度并禁用）
  Widget _buildBottomActionBar(ThemeData theme, S loc) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withAlpha((0.08 * 255).round()),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _uploading ? null : () => _submit(asDraft: true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(46.h),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withAlpha(140),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                  child: Text(
                    loc.saveDraft,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _uploading ? null : () => _submit(asDraft: false),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(46.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                  child: _uploading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14.r,
                              height: 14.r,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              loc.uploadingPercent(_uploadPercent),
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ],
                        )
                      : Text(
                          loc.submitPublish,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 引导页大按钮（主操作实心 / 次操作描边）
class _GuideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _GuideButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100.r),
    );

    Widget button;
    if (filled) {
      button = FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20.sp),
        label: Text(
          label,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          minimumSize: Size(240.w, 52.h),
          shape: shape,
        ),
      );
    } else {
      button = OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20.sp),
        label: Text(
          label,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(240.w, 52.h),
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary.withAlpha(140)),
          shape: shape,
        ),
      );
    }
    return button;
  }
}

/// 预览卡上的胶囊小按钮（图标 + 可选文字，半透明黑底）
class _PreviewPillButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  const _PreviewPillButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(100.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14.sp, color: Colors.white),
                if (label != null) ...[
                  SizedBox(width: 4.w),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        _error = localizedErrorText(S.of(context), e);
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
      EasyLoading.showToast(localizedErrorText(loc, e));
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
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${draft.duration}s · ${draft.tags.map((t) => '#$t').join(' ')}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          // 已挂靠剧集：草稿提交发布时自动挂回该剧（服务端排集号）
                          if (draft.seriesId > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 2.h),
                              child: Text(
                                draft.episodeNumber > 0
                                    ? loc.draftSeriesBadge(draft.episodeNumber)
                                    : loc.draftSeriesAttached,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
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
