import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/app_router/app_router.dart'
    show RouteNames;
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/themes/app_colors.dart';
import 'package:shortplay_app/src/core/transport/http/index.dart'
    show ApiStatusException, localizedErrorText;
import 'package:shortplay_app/src/core/widgets/empty_state.dart';
import 'package:shortplay_app/src/core/widgets/gradient_button.dart';
import 'package:shortplay_app/src/features/common/data/models.dart';
import 'package:shortplay_app/src/features/common/widgets/cover_image.dart';
import 'package:shortplay_app/src/features/series/services/series_service.dart';

/// 剧集详情页（剧信息头 + 选集列表）
///
/// 可见性跟随视频审核状态（游客仅见已发布集）；作者本人可编辑/删除剧集。
/// 点击选集进入单视频沉浸详情页；[currentVideoId] 用于高亮来源集。
class SeriesDetailPage extends StatefulWidget {
  final int seriesId;

  /// 来源集（从视频详情进入时传入，列表高亮）
  final int? currentVideoId;

  const SeriesDetailPage({
    super.key,
    required this.seriesId,
    this.currentVideoId,
  });

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  final SeriesService _seriesService = SeriesService();

  SeriesDetail? _detail;
  String? _error;
  bool _loading = true;

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
      final detail = await _seriesService.getSeries(widget.seriesId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizedErrorText(S.of(context), e);
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

  bool get _isMine =>
      GetIt.instance<UserAuthCache>().userId > 0 &&
      GetIt.instance<UserAuthCache>().userId == _detail?.series?.authorId;

  Future<void> _editSeries() async {
    final loc = S.of(context);
    final series = _detail?.series;
    if (series == null) return;

    final titleController = TextEditingController(text: series.title);
    final descController = TextEditingController(text: series.description);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.editSeries,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: titleController,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: loc.seriesTitleLabel,
                  counterText: '',
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: descController,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: loc.seriesDescLabel,
                  counterText: '',
                ),
              ),
              SizedBox(height: 16.h),
              GradientButton(
                label: loc.save,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true || !mounted) return;
    try {
      await _seriesService.updateSeries(
        seriesId: series.id,
        title: titleController.text.trim(),
        description: descController.text.trim(),
      );
      if (!mounted) return;
      EasyLoading.showToast(S.of(context).seriesSaved);
      _load();
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      EasyLoading.showToast(localizedErrorText(S.of(context), e));
    } catch (_) {
      if (!mounted) return;
      EasyLoading.showToast(S.of(context).errorOccurred);
    }
  }

  Future<void> _deleteSeries() async {
    final loc = S.of(context);
    final series = _detail?.series;
    if (series == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.deleteSeriesTitle),
        content: Text(loc.deleteSeriesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _seriesService.deleteSeries(series.id);
      if (!mounted) return;
      EasyLoading.showToast(loc.seriesDeleted);
      context.pop(true);
    } on ApiStatusException catch (e) {
      if (!mounted) return;
      EasyLoading.showToast(localizedErrorText(S.of(context), e));
    } catch (_) {
      if (!mounted) return;
      EasyLoading.showToast(loc.errorOccurred);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final detail = _detail;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || detail?.series == null
              ? EmptyState(
                  icon: Icons.movie_filter_outlined,
                  title: _error ?? loc.seriesNotFound,
                  actionLabel: loc.retry,
                  onAction: _load,
                )
              : _buildContent(loc, detail!),
    );
  }

  Widget _buildContent(S loc, SeriesDetail detail) {
    final series = detail.series!;
    final theme = Theme.of(context);

    // 封面回退：剧未设封面时用第一集封面
    final coverUrl = series.coverUrl.isNotEmpty
        ? series.coverDisplayUrl
        : (detail.items.isNotEmpty ? detail.items.first.coverDisplayUrl : '');

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 232.h,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: Colors.white,
            actions: [
              if (_isMine)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: loc.editSeries,
                  onPressed: _editSeries,
                ),
              if (_isMine)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: loc.delete,
                  onPressed: _deleteSeries,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    CoverImage(
                      url: coverUrl,
                      borderRadius: BorderRadius.zero,
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(gradient: BrandColor.gradient),
                    ),
                  // 底部渐变遮罩（封面压深，白字可读）
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(70),
                          Colors.black.withAlpha(30),
                          Colors.black.withAlpha(190),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16.w,
                    right: 16.w,
                    bottom: 14.h,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          loc.seriesUpdatedTo(
                            series.publishedCount,
                            series.episodeCount,
                          ),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                        if (series.description.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            series.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withAlpha(190),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            sliver: detail.items.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.movie_filter_outlined,
                      title: loc.seriesEmpty,
                    ),
                  )
                : SliverList.separated(
                    itemCount: detail.items.length,
                    separatorBuilder: (_, _) => SizedBox(height: 4.h),
                    itemBuilder: (context, index) {
                      final video = detail.items[index];
                      return _EpisodeTile(
                        video: video,
                        episodeNumber: index + 1,
                        isCurrent:
                            widget.currentVideoId != null &&
                                video.id == widget.currentVideoId,
                        showStatusBadge: _isMine,
                        onTap: () => context.pushNamed(
                          RouteNames.videoDetail,
                          pathParameters: {
                            'videoId': '${video.id}',
                          },
                        ),
                      );
                    },
                  ),
          ),
          // 底部安全垫
          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
        ],
      ),
    );
  }
}

/// 选集条目：集号 + 封面 + 标题 + 时长（本人可见状态角标；当前集品牌高亮）
class _EpisodeTile extends StatelessWidget {
  final Video video;
  final int episodeNumber;
  final bool isCurrent;
  final bool showStatusBadge;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.video,
    required this.episodeNumber,
    required this.isCurrent,
    required this.showStatusBadge,
    required this.onTap,
  });

  String? _statusBadge(S loc) {
    switch (video.status) {
      case VideoStatus.reviewing:
        return loc.statusReviewing;
      case VideoStatus.rejected:
        return loc.statusRejected;
      case VideoStatus.offline:
        return loc.statusOffline;
      case VideoStatus.draft:
        return loc.statusDraft;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = S.of(context);
    final badge = _statusBadge(loc);

    final totalSeconds = video.duration;
    final duration = totalSeconds > 0
        ? '${totalSeconds ~/ 60}:${(totalSeconds % 60).toString().padLeft(2, '0')}'
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: isCurrent
              ? BrandColor.rose.withAlpha(18)
              : Colors.transparent,
          border: isCurrent
              ? Border.all(color: BrandColor.rose.withAlpha(120))
              : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CoverImage(
                  url: video.coverDisplayUrl,
                  width: 96.w,
                  height: 64.h,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                if (duration.isNotEmpty)
                  Positioned(
                    right: 4.w,
                    bottom: 4.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 5.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        duration,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.episodeN(episodeNumber),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? BrandColor.rose
                          : theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (badge != null && showStatusBadge) ...[
                    SizedBox(height: 3.h),
                    Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isCurrent)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  gradient: BrandColor.gradient,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  loc.playNow,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
