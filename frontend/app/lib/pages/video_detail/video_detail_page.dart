import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/video_detail_cubit.dart';
import '../../core/config.dart';
import '../../core/route_observer.dart';
import '../../models/user.dart';
import '../../models/video.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../comment/comment_sheet.dart';
import '../feed/feed_video_item.dart';
import '../login/login_page.dart';
import '../user/user_page.dart';

/// 单视频沉浸式详情页：从消息 / 搜索 / 作品列表进入。
///
/// 复用 Feed 的单页播放组件 [FeedVideoItem]，本页实现
/// [VideoItemActions] 把数据操作接到 [VideoDetailCubit]。
class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({super.key, required this.videoId});

  final int videoId;

  /// 打开单视频详情页。
  static Future<void> push(BuildContext context, int videoId) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoDetailPage(videoId: videoId)),
    );
  }

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage>
    with RouteAware
    implements VideoItemActions {
  late final VideoDetailCubit _cubit;

  final Map<int, User> _authorCache = {};
  bool _routeObscured = false;

  @override
  void initState() {
    super.initState();
    _cubit = VideoDetailCubit(widget.videoId)..load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _cubit.close();
    super.dispose();
  }

  // RouteAware：评论弹窗等上层路由盖住时暂停视频。
  @override
  void didPushNext() {
    if (!_routeObscured) setState(() => _routeObscured = true);
  }

  @override
  void didPopNext() {
    if (_routeObscured) setState(() => _routeObscured = false);
  }

  /// 「更多」菜单：目前提供举报入口。
  Future<void> _showMoreMenu() async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1D1D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.white70),
              title: const Text('举报', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop('report'),
            ),
          ],
        ),
      ),
    );
    if (action != 'report' || !mounted) return;
    await _showReportSheet();
  }

  /// 举报原因选择 BottomSheet + 提交（POST /reports）。
  Future<void> _showReportSheet() async {
    final video = _cubit.state.video;
    if (video == null) return;
    final error = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _ReportSheet(videoId: video.id),
    );
    if (!mounted) return;
    // sheet 返回错误信息时提示；null 表示用户取消或提交成功。
    if (error != null) {
      showToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VideoDetailCubit>.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<VideoDetailCubit, VideoDetailState>(
          builder: (context, state) {
            final video = state.video;
            if (state.loading && video == null) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              );
            }
            if (state.error != null && video == null) {
              return ErrorRetryView(
                message: state.error ?? '加载失败',
                onRetry: _cubit.load,
              );
            }
            if (video == null) {
              return const EmptyView(icon: Icons.movie_outlined, text: '视频不存在');
            }
            return FeedVideoItem(
              video: video,
              isActive: !_routeObscured,
              actions: this,
              onBack: () => Navigator.of(context).pop(),
              moreActions: [
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  tooltip: '更多',
                  onPressed: _showMoreMenu,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- VideoItemActions（数据操作接 VideoDetailCubit） ----

  @override
  bool isLiked(Video video) => _cubit.state.liked;

  @override
  bool isCollected(Video video) => _cubit.state.collected;

  @override
  bool isFollowing(User author) =>
      _cubit.state.author?.id == author.id && _cubit.state.following;

  @override
  int likeCountOf(Video video) => _cubit.state.likeCount;

  @override
  int collectCountOf(Video video) => _cubit.state.collectCount;

  @override
  int commentCountOf(Video video) =>
      video.commentCount + _cubit.state.commentCountDelta;

  @override
  Future<User?> loadAuthor(int userId) async {
    if (userId <= 0) return null;
    // 详情接口已带回作者信息，优先使用。
    final fromState = _cubit.state.author;
    if (fromState != null && fromState.id == userId) return fromState;
    final cached = _authorCache[userId];
    if (cached != null) return cached;
    try {
      final user = await Services.user.user(userId);
      _authorCache[userId] = user;
      return user;
    } on ApiException {
      return null;
    }
  }

  @override
  Future<void> toggleLike(Video video) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final ok = await _cubit.toggleLike();
    if (!ok && mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  Future<void> toggleCollect(Video video) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final ok = await _cubit.toggleCollect();
    if (!ok && mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  Future<void> toggleFollow(User author) async {
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final ok = await _cubit.toggleFollow();
    if (!ok && mounted) showToast(context, '操作失败，请稍后重试');
  }

  @override
  void openComments(Video video) {
    CommentSheet.show(
      context,
      video: video,
      onCountChanged: (delta) => _cubit.bumpCommentCount(delta),
    );
  }

  @override
  void share(Video video) {
    // 分享链接：http://<API_BASE>/s/{videoId}（后端 H5 预览页）。
    Clipboard.setData(
      ClipboardData(text: '${AppConfig.shareBase}/s/${video.id}'),
    );
    showToast(context, '链接已复制，快去分享吧');
  }

  @override
  void openAuthor(User author) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserPage(userId: author.id)),
    );
  }
}

/// 举报原因选择面板。
///
/// 提交成功后关闭；失败（含 409 DUPLICATE_REPORT）返回错误文案给调用方提示。
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.videoId});

  final int videoId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String _reason = ReportService.reasons.first.$2;
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await Services.report.report(
        targetType: 1,
        targetId: widget.videoId,
        reason: _reason,
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      showToast(context, '举报已提交，感谢您的反馈');
      Navigator.of(context).pop(null);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.isReason('DUPLICATE_REPORT')
          ? '该内容已被举报过，请勿重复提交'
          : e.message;
      Navigator.of(context).pop(msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Text(
                    '举报视频',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            // 原因单选（RadioGroup 管理选中态）。
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) {
                if (v != null) setState(() => _reason = v);
              },
              child: Column(
                children: ReportService.reasons
                    .map(
                      (r) => RadioListTile<String>(
                        value: r.$2,
                        activeColor: const Color(0xFFFF4D67),
                        title: Text(
                          r.$1,
                          style: const TextStyle(color: Colors.white),
                        ),
                        dense: true,
                      ),
                    )
                    .toList(),
              ),
            ),
            // 补充说明。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _descCtrl,
                maxLength: 200,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '补充说明（选填，最多 200 字）',
                  counterText: '',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '提交中…' : '提交举报'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
