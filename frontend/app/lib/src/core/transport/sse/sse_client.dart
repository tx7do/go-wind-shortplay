import 'dart:async' show StreamController, Timer;
import 'dart:convert' show utf8;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' show GetIt;

import 'package:shortplay_app/src/core/config/environments.dart';
import 'package:shortplay_app/src/core/repositories/user_auth_cache.dart';
import 'package:shortplay_app/src/core/utilities/logger.dart' show debug;

/// SSE 事件（服务端 `event:` + `data:` 一帧）
class SseMessage {
  /// 事件名（sseevent 双边约定：notification / im-message）
  final String event;

  /// 载荷（JSON 字符串）
  final String data;

  const SseMessage({required this.event, required this.data});
}

/// 轻量 SSE 客户端（自研：dio 字节流按行解析，无第三方依赖）
///
/// - 连接 `GET {sseBaseUrl}/events?streamId=<token>&token=<token>`
///   （streamID 约定 = access token，与 admin 面同构；一个 token 一个在线端）
/// - 登录后 [start]，登出 [stop]；断线指数退避自动重连（2s→60s 封顶）
/// - 落库为准：SSE 只管实时性，丢失靠 REST 拉取对账，客户端不做 Last-Event-ID 补偿
class SseClient {
  SseClient();

  final Dio _dio = Dio();
  final StreamController<SseMessage> _events =
      StreamController<SseMessage>.broadcast();

  CancelToken? _cancelToken;
  Timer? _retryTimer;
  int _retrySeconds = 2;
  bool _stopped = true;

  /// 跨 chunk 行缓冲（SSE 按 \n 分行，分块边界可能切在行中）
  String _lineBuffer = '';

  bool get _hasLogin => GetIt.instance<UserAuthCache>().hasLogin;

  /// 事件流（broadcast：聊天页/会话列表/角标各自订阅）
  Stream<SseMessage> get events => _events.stream;

  /// 是否在线
  bool get connected => !_stopped;

  /// 启动（幂等）：登录后调用；内部监听登录态，登出自动停
  void attach() {
    final notifier = GetIt.instance<UserAuthCache>().loginStateNotifier;
    notifier.removeListener(_onLoginStateChanged);
    notifier.addListener(_onLoginStateChanged);
    _onLoginStateChanged();
  }

  void _onLoginStateChanged() {
    if (_hasLogin) {
      start();
    } else {
      stop();
    }
  }

  /// 建立连接（已连接时忽略）
  void start() {
    if (!_stopped || !_hasLogin) return;
    _stopped = false;
    _retrySeconds = 2;
    _connect();
  }

  /// 停止（登出/退出）
  void stop() {
    _stopped = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  Future<void> _connect() async {
    if (_stopped || !_hasLogin) return;
    final token = GetIt.instance<UserAuthCache>().accessToken!;
    final base = Environments.sseBaseUrl.replaceAll(RegExp('/+\$'), '');
    _cancelToken = CancelToken();
    try {
      final res = await _dio.get<ResponseBody>(
        '$base/events',
        queryParameters: {'streamId': token, 'token': token},
        options: Options(
          responseType: ResponseType.stream,
          // 长连接：禁收包超时（dio 不支持 per-request 禁用时给极大值）
          receiveTimeout: const Duration(minutes: 60 * 24 * 7),
          headers: {'Accept': 'text/event-stream'},
          extra: {'sse': true},
        ),
        cancelToken: _cancelToken,
      );
      final stream = res.data;
      if (stream == null) throw StateError('empty sse stream');
      debug('sse connected');
      _retrySeconds = 2;
      await for (final chunk in stream.stream) {
        if (_stopped) return;
        _lineBuffer += utf8.decode(chunk, allowMalformed: true);
        // 只处理完整行；行中残留留给下一 chunk
        final endsWithNewline = _lineBuffer.endsWith('\n');
        final lines = _lineBuffer.split('\n');
        _lineBuffer = endsWithNewline ? '' : lines.removeLast();
        for (final message in _parseLines(lines)) {
          _events.add(message);
        }
      }
      // 服务端正常关闭（或网络断）：走重连
      _scheduleReconnect();
    } catch (e) {
      if (_stopped) return;
      debug('sse disconnected (ignored): $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_stopped || !_hasLogin) return;
    _lineBuffer = '';
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retrySeconds), () {
      if (_stopped || !_hasLogin) return;
      _retrySeconds = (_retrySeconds * 2).clamp(2, 60);
      _connect();
    });
  }

  /// 把完整行聚合成 SSE 消息（按空行分帧；重连时清空行缓冲）
  Iterable<SseMessage> _parseLines(List<String> lines) sync* {
    String event = '';
    final data = StringBuffer();
    for (final rawLine in lines) {
      final line = rawLine.replaceFirst(RegExp('\r\$'), '');
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          yield SseMessage(
            event: event.isEmpty ? 'message' : event,
            data: data.toString(),
          );
        }
        event = '';
        data.clear();
        continue;
      }
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.write(line.substring(5).trim());
      }
      // id:/retry: 忽略（不做 Last-Event-ID 补偿，落库为准）
    }
  }
}

/// 全局单例（App 启动时 attach 一次）
final SseClient sseClient = SseClient();
