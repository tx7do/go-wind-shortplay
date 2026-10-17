import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 轻提示（统一 SnackBar 样式）。
void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1800),
      ),
    );
}

/// 数量格式化：超过 1 万显示 x.x万。
String formatCount(int n) {
  if (n >= 10000) {
    final v = n / 10000;
    return v >= 100 ? '${v.toStringAsFixed(0)}万' : '${v.toStringAsFixed(1)}万';
  }
  return '$n';
}

/// 相对时间格式化：刚刚 / n分钟前 / n小时前 / n天前 / 日期。
String formatRelativeTime(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// 用户头像（支持点击），无头像时显示首字符。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.url,
    this.name = '',
    this.radius = 18,
    this.onTap,
    this.borderColor,
  });

  final String url;
  final String name;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      backgroundImage:
          url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? Text(
              name.isNotEmpty ? name.characters.first : '?',
              style: const TextStyle(color: Colors.white),
            )
          : null,
    );
    final bordered = borderColor == null
        ? avatar
        : CircleAvatar(
            radius: radius + 1.5,
            backgroundColor: borderColor,
            child: avatar,
          );
    if (onTap == null) return bordered;
    return GestureDetector(onTap: onTap, child: bordered);
  }
}

/// 空态视图。
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.white30),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

/// 加载失败重试视图。
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, this.message = '加载失败', this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52, color: Colors.white38),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 列表底部加载更多指示器。
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.loading,
    required this.hasMore,
  });

  final bool loading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '没有更多了',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
