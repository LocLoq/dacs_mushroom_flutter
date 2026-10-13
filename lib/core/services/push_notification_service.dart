import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../network/api_config.dart';
import '../network/farm_api.dart';
import '../storage/local_session.dart';
import 'workflow_refresh_service.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../widgets/async_views.dart';

const _contextKey = 'push_registration_context';
bool storedSessionMatchesContext(Map? session, Map context) {
  if (session?['server'] != context['origin']) return false;
  try {
    final token = session!['token'] as String;
    final payload =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            )
            as Map;
    return payload['id'] == context['user'];
  } catch (_) {
    return false;
  }
}

bool pushMatchesContext(Map message, Map context) =>
    context['registrationId'] is String &&
    message['registrationId'] == context['registrationId'] &&
    message['userId'] == '${context['user']}' &&
    message['origin'] == context['origin'];
Future<Map<String, dynamic>?> _context() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final value = prefs.getString(_contextKey);
  return value == null
      ? null
      : Map<String, dynamic>.from(jsonDecode(value) as Map);
}

Future<void> _saveContext(Map<String, dynamic> value) async {
  await (await SharedPreferences.getInstance()).setString(
    _contextKey,
    jsonEncode(value),
  );
}

@pragma('vm:entry-point')
Future<void> mushroomBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // OS displays a generic notification. Opening always rechecks the current
  // account, registration and API permissions in the foreground.
}

class PushNotificationService with WidgetsBindingObserver {
  static final instance = PushNotificationService();
  static const enabled = bool.fromEnvironment(
    'PUSH_ENABLED',
    defaultValue: true,
  );
  final status = ValueNotifier<String>('Thông báo đẩy chưa sẵn sàng');
  GlobalKey<NavigatorState>? _navigator;
  Map? _pending;
  String? _deviceToken;
  bool _started = false, _opening = false;
  Timer? _retry;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _syncing = Future.value();
  Future<void> start(GlobalKey<NavigatorState> navigator) async {
    _navigator = navigator;
    if (_started ||
        !enabled ||
        kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform))
      return;
    try {
      await Firebase.initializeApp();
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      FirebaseMessaging.onBackgroundMessage(mushroomBackgroundMessage);
      LocalSession.changes.addListener(_changed);
      ApiConfig.changes.addListener(_changed);
      LocalSession.beforeLogout.add(_logout);
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          _deviceToken = token;
          _changed();
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(
          (message) => unawaited(_foreground(message)),
        ),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => open(message.data),
        ),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pending = initial.data;
      _changed();
    } catch (_) {
      status.value = 'Chưa có cấu hình Firebase trong ứng dụng.';
      stop();
    }
  }

  Future<void> _foreground(RemoteMessage message) async {
    final context = await _context();
    if (context == null ||
        !LocalSession.isLoggedIn ||
        !pushMatchesContext(message.data, context) ||
        context['origin'] != ApiConfig.origin ||
        context['user'] != LocalSession.userId)
      return;
    WorkflowRefreshService.instance.refreshAll();
    final navigator = _navigator?.currentState;
    if (navigator != null && navigator.mounted)
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        SnackBar(
          content: const Text('Có cập nhật công việc'),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => open(message.data),
          ),
        ),
      );
  }

  void _changed() {
    _syncing = _syncing.then((_) => _sync()).catchError((Object e) {
      status.value = 'Đăng ký thông báo chưa thành công. Sẽ thử lại.';
      _retry?.cancel();
      if (_started && LocalSession.isLoggedIn)
        _retry = Timer(const Duration(seconds: 5), _changed);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _changed();
  }

  void stop() {
    _started = false;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LocalSession.changes.removeListener(_changed);
    ApiConfig.changes.removeListener(_changed);
    LocalSession.beforeLogout.remove(_logout);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  Future<void> unregister() async {
    final context = await _context();
    await (await SharedPreferences.getInstance()).remove(_contextKey);
    if (context == null ||
        context['provider'] != 'fcm' ||
        context['token'] == null ||
        context['registrationId'] == null)
      return;
    final session = await LocalSession.store.read();
    if (!storedSessionMatchesContext(session, context)) return;
    await _cancelRegistration(
      context['origin'] as String,
      session!['token'] as String,
      context['token'] as String,
      context['registrationId'] as String,
    );
  }

  Future<void> _cancelRegistration(
    String origin,
    String auth,
    String token,
    String id,
  ) async {
    try {
      await http
          .delete(
            Uri.parse('$origin/api/notifications/devices'),
            headers: {
              'Authorization': 'Bearer $auth',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Tunnel-Skip-AntiPhishing-Page': 'true',
            },
            body: jsonEncode({'token': token, 'registrationId': id}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _logout() async {
    await unregister();
    _retry?.cancel();
    _deviceToken = null;
    _pending = null;
    if (_started) {
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }

  Future<void> registerAgain() async {
    if (!_started && _navigator != null) await start(_navigator!);
    if (!_started) return;
    await _logout();
    _changed();
  }

  Future<void> _sync() async {
    if (!_started) return;
    if (!LocalSession.isLoggedIn) {
      if (await LocalSession.store.read() == null) await _logout();
      return;
    }
    final origin = ApiConfig.origin,
        user = LocalSession.userId,
        auth = LocalSession.tokenFor(ApiConfig.origin);
    if (auth == null || user == null) return;
    final response = await FarmApi.instance.get('/notifications/push-config');
    if (origin != ApiConfig.origin ||
        user != LocalSession.userId ||
        auth != LocalSession.tokenFor(origin))
      return;
    final config = response['data'] as Map;
    var context = await _context();
    if (context != null &&
        (context['provider'] != 'fcm' ||
            context['origin'] != origin ||
            context['serverOrigin'] != origin ||
            context['user'] != user ||
            context['version'] != config['version'] ||
            _deviceToken != null && _deviceToken != context['token'])) {
      await unregister();
      context = null;
    }
    if ((config['channels'] as Map)['fcm'] != true) {
      status.value =
          'Máy chủ chưa bật thông báo đẩy. Thông báo trong app vẫn hoạt động.';
      return;
    }
    if (config['projectId'] != null &&
        Firebase.app().options.projectId != config['projectId']) {
      status.value = 'Cấu hình thông báo của ứng dụng và máy chủ chưa khớp.';
      return;
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      status.value = 'Bạn chưa cho phép thông báo trên thiết bị.';
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      status.value = 'Đang chờ đăng ký thông báo iOS';
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 2), _changed);
      return;
    }
    _deviceToken ??= await FirebaseMessaging.instance.getToken();
    final token = _deviceToken;
    if (token == null ||
        origin != ApiConfig.origin ||
        user != LocalSession.userId ||
        auth != LocalSession.tokenFor(origin))
      return;
    if (context == null) {
      final registered = await FarmApi.instance.put('/notifications/devices', {
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'provider': 'fcm',
        'token': token,
        'serverOrigin': origin,
      });
      final id = (registered['data'] as Map)['registrationId'] as String;
      if (origin != ApiConfig.origin ||
          user != LocalSession.userId ||
          auth != LocalSession.tokenFor(origin)) {
        await _cancelRegistration(origin, auth, token, id);
        return;
      }
      await _saveContext({
        'origin': origin,
        'serverOrigin': origin,
        'user': user,
        'token': token,
        'registrationId': id,
        'provider': 'fcm',
        'version': config['version'],
      });
    }
    status.value = 'Đã đăng ký thông báo trên thiết bị';
    unawaited(_tryOpen());
  }

  void open(Map message) {
    _pending = message;
    unawaited(_tryOpen());
  }

  Future<void> _tryOpen() async {
    final message = _pending, navigator = _navigator?.currentState;
    if (_opening || message == null || !LocalSession.isLoggedIn) return;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_tryOpen()),
      );
      return;
    }
    final context = await _context();
    if (context == null ||
        !pushMatchesContext(message, context) ||
        message['origin'] != ApiConfig.origin ||
        message['userId'] != '${LocalSession.userId}') {
      _pending = null;
      return;
    }
    _opening = true;
    final origin = ApiConfig.origin, user = LocalSession.userId;
    try {
      final id = message['notificationId'];
      if (id is! String) return;
      final response = await FarmApi.instance.get('/notifications/$id');
      if (origin != ApiConfig.origin || user != LocalSession.userId) return;
      await FarmApi.instance.patch('/notifications/$id/read', {});
      WorkflowRefreshService.instance.refreshAll();
      final taskId = (response['data'] as Map?)?['taskId'] as String?;
      if (taskId == null) return;
      await FarmApi.instance.get('/dashboard/tasks/$taskId');
      if (origin != ApiConfig.origin || user != LocalSession.userId) return;
      await navigator.push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
      );
    } on ApiException catch (e) {
      if (navigator.mounted)
        toast(
          navigator.context,
          e.isForbidden
              ? 'Bạn không còn quyền truy cập công việc này.'
              : e.message,
          error: true,
        );
    } finally {
      _pending = null;
      _opening = false;
    }
  }
}
