import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_config.dart';
import '../network/farm_api.dart';
import '../network/mock_config.dart';
import '../storage/local_session.dart';

class RefreshSignal {
  const RefreshSignal(this.resource, [this.id, this.reset = false]);
  final String resource;
  final Object? id;
  final bool reset;
  bool matches(List<String> resources, Object? target) =>
      resource == '*' ||
      resource == 'permissions' ||
      (resources.contains(resource) &&
          (id == null || target == null || '$id' == '$target'));
}

class WorkflowRefreshService with WidgetsBindingObserver {
  WorkflowRefreshService();
  static final instance = WorkflowRefreshService();
  final unreadCount = ValueNotifier<int>(0);
  final _events = StreamController<RefreshSignal>.broadcast();
  Stream<RefreshSignal> get events => _events.stream;
  final Map<String, RefreshSignal> _pending = {};
  Timer? _debounce;
  io.Socket? _socket;
  bool _started = false;
  String? _identity;
  int _generation = 0;
  int _notificationTicket = 0;
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    LocalSession.changes.addListener(_sync);
    ApiConfig.changes.addListener(_sync);
    _sync();
  }

  void stop() {
    _started = false;
    _generation++;
    LocalSession.changes.removeListener(_sync);
    ApiConfig.changes.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _socket = null;
    _debounce?.cancel();
    _pending.clear();
    _identity = null;
  }

  void _sync() {
    final token = LocalSession.isLoggedIn
        ? (MockConfig.enabled
              ? LocalSession.token
              : LocalSession.tokenFor(ApiConfig.origin))
        : null;
    final identity = token == null ? null : '${ApiConfig.origin}:$token';
    if (_identity == identity) return;
    _identity = identity;
    _generation++;
    _socket?.dispose();
    _socket = null;
    _debounce?.cancel();
    _pending.clear();
    unreadCount.value = 0;
    _events.add(const RefreshSignal('*', null, true));
    if (!LocalSession.isLoggedIn) return;
    unawaited(reloadNotifications());
    if (MockConfig.enabled || token == null) return;
    _socket = io.io(
      '${ApiConfig.origin}/workflow',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Accept': 'application/json', 'X-Tunnel-Skip-AntiPhishing-Page': 'true'})
          .enableForceNew()
          .enableReconnection()
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.onConnect((_) => refreshAll());
    _socket!.on('refresh', (data) {
      if (data is Map && data['resource'] is String) {
        invalidate(data['resource'] as String, data['id']);
      }
    });
    _socket!.onConnectError((error) {
      if (error.toString().contains('AUTH_INVALID_TOKEN'))
        _socket?.disconnect();
    });
    _socket!.connect();
  }

  void invalidate(String resource, [Object? id]) {
    const allowed = {
      'tasks',
      'notifications',
      'batches',
      'care-logs',
      'growth-progress',
      'harvests',
      'permissions',
    };
    if (!allowed.contains(resource)) return;
    _pending['$resource:$id'] = RefreshSignal(resource, id);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final signals = _pending.values.toList();
      _pending.clear();
      for (final signal in signals) {
        _events.add(signal);
      }
      if (signals.any(
        (s) => s.resource == 'notifications' || s.resource == 'permissions',
      )) {
        unawaited(reloadNotifications());
      }
    });
  }

  void refreshAll() {
    _events.add(const RefreshSignal('*'));
    unawaited(reloadNotifications());
  }

  Future<Map<String, dynamic>> loadNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final generation = _generation;
    final ticket = ++_notificationTicket;
    final data = await FarmApi.instance.get(
      '/notifications',
      query: {'page': page, 'limit': limit},
    );
    if (generation == _generation && ticket == _notificationTicket) {
      unreadCount.value = (data['unreadCount'] as num?)?.toInt() ?? 0;
    }
    return data;
  }

  Future<void> reloadNotifications() async {
    if (!LocalSession.isLoggedIn) return;
    try {
      await loadNotifications(limit: 1);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshAll();
  }
}
