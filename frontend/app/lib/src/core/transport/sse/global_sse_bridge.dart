import 'dart:async' show StreamSubscription, Timer;
import 'dart:convert' show JsonDecoder;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/preference/user_preference_cache.dart';
import 'package:shortplay_app/src/core/transport/sse/sse_client.dart';
import 'package:shortplay_app/src/features/notify/bloc/notify_bloc.dart';

/// 全局 SSE 消费桥：订阅实时事件驱动全局 UI 反馈。
///
/// - `notification`（站内信/系统通知）：刷新消息 tab 未读角标 + 顶部 Toast
///   （载荷为 admin 面 "notification" 事件的收件行 JSON 形态——双边约定）
/// - `im-message`（私信新消息）：刷新未读角标（聊天/会话页各自消费细粒度）
///
/// 挂在 _HomeShell 之上（BlocProvider 内），登出后 SSE 自动断开无事件。
class GlobalSseBridge extends StatefulWidget {
  final Widget child;

  const GlobalSseBridge({super.key, required this.child});

  @override
  State<GlobalSseBridge> createState() => _GlobalSseBridgeState();
}

class _GlobalSseBridgeState extends State<GlobalSseBridge> {
  StreamSubscription<SseMessage>? _sub;
  Timer? _teenTimer;

  @override
  void initState() {
    super.initState();
    _sub = sseClient.events.listen(_onEvent);
    // 青少年模式计时（每分钟一跳；App 活跃期即观看期近似）
    _teenTimer = Timer.periodic(const Duration(minutes: 1), (_) => _teenTick());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _teenTimer?.cancel();
    super.dispose();
  }

  /// 青少年模式：当日累计观看分钟 +1，满 40 分钟提醒一次（跨日自动重置）
  Future<void> _teenTick() async {
    final prefs = GetIt.instance<UserPreferenceCache>();
    if (!prefs.teenModeEnabled) return;
    final now = DateTime.now();
    final stamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    var minutes = prefs.teenTodayMinutes;
    if (prefs.teenDayStamp != stamp) {
      minutes = 0;
      await prefs.setTeenDayStamp(stamp);
    }
    minutes += 1;
    await prefs.setTeenTodayMinutes(minutes);
    if (minutes == 40 && mounted) {
      final loc = S.of(context);
      EasyLoading.showToast(
        loc.teenRestMessage,
        duration: const Duration(seconds: 5),
        toastPosition: EasyLoadingToastPosition.center,
      );
    }
  }

  void _onEvent(SseMessage m) {
    if (!mounted) return;
    switch (m.event) {
      case 'notification':
        context.read<NotifyBloc>().add(const NotifyUnreadCountRefreshed());
        _toastNotification(m.data);
      case 'im-message':
        // 私信未读与通知未读不同源：刷新通知角标不合适；
        // 会话/聊天页各自消费，此处仅兜底刷通知计数（未来 IM 角标挂这里）
        break;
      default:
        break;
    }
  }

  void _toastNotification(String data) {
    String title = '';
    String content = '';
    try {
      final decoded = (const JsonDecoder()).convert(data);
      if (decoded is Map<String, dynamic>) {
        title = decoded['title'] ?? '';
        content = decoded['content'] ?? '';
      }
    } catch (_) {
      return;
    }
    final text = content.isNotEmpty ? content : title;
    if (text.isEmpty) return;
    EasyLoading.showToast(
      text,
      duration: const Duration(seconds: 3),
      toastPosition: EasyLoadingToastPosition.top,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
