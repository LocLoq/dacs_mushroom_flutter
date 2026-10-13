import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:http/http.dart' as http;
import '../network/api_config.dart';
import '../network/farm_api.dart';
import '../storage/local_session.dart';
import 'workflow_refresh_service.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../widgets/async_views.dart';

const _contextKey = 'push_registration_context';
final _local = FlutterLocalNotificationsPlugin();
const _apns = MethodChannel('com.example.thu/apns');
Future<Map<String, dynamic>?> _pushContext() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final raw = prefs.getString(_contextKey);
  return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

Future<void> _writeContext(Map<String, dynamic> value) async {
  await (await SharedPreferences.getInstance()).setString(
    _contextKey,
    jsonEncode(value),
  );
}

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
    message['userId'] == '${context['user']}' &&
    message['origin'] == context['origin'] &&
    message['registrationId'] == context['registrationId'];
Future<void> _localInit() async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (response) {
      if (response.payload != null)
        PushNotificationService.instance.open(
          jsonDecode(response.payload!) as Map,
        );
    },
  );
}

@pragma('vm:entry-point')
Future<void> initializeUnifiedPush() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await _localInit();
  await UnifiedPush.initialize(
    onNewEndpoint: (endpoint, instance) =>
        unawaited(_endpoint(endpoint, instance)),
    onMessage: (message, instance) => unawaited(_receive(message, instance)),
    onUnregistered: (instance) => unawaited(_revoked(instance)),
    onRegistrationFailed: (reason, instance) =>
        PushNotificationService.instance.status.value =
            'Không đăng ký được UnifiedPush: $reason',
    onTempUnavailable: (_) => PushNotificationService.instance.status.value =
        'Máy chủ thông báo tạm thời không kết nối được.',
  );
}

Future<void> _endpoint(PushEndpoint endpoint, String instance) async {
  try {
    final context = await _pushContext();
    if (context == null ||
        context['instance'] != instance ||
        endpoint.temporary ||
        endpoint.pubKeySet == null)
      return;
    if (Uri.parse(endpoint.url).origin !=
        Uri.parse(context['ntfyUrl'] as String).origin) {
      PushNotificationService.instance.status.value =
          'Distributor dùng máy chủ khác. Cấu hình URL ntfy rồi đăng ký lại.';
      return;
    }
    final session = await LocalSession.store.read();
    if (!storedSessionMatchesContext(session, context)) return;
    final response = await http
        .put(
          Uri.parse('${context['origin']}/api/notifications/devices'),
          headers: {
            'Authorization': 'Bearer ${session!['token']}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Tunnel-Skip-AntiPhishing-Page': 'true',
          },
          body: jsonEncode({
            'platform': 'android',
            'provider': 'unifiedpush',
            'token': endpoint.url,
            'keys': {
              'p256dh': endpoint.pubKeySet!.pubKey,
              'auth': endpoint.pubKeySet!.auth,
            },
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200)
      throw StateError('Đăng ký endpoint: HTTP ${response.statusCode}');
    final registrationId =
        (jsonDecode(response.body)['data'] as Map)['registrationId'];
    if ((await _pushContext())?['instance'] != instance) {
      // Registration may finish after logout. Cancel it using the captured session.
      await http.delete(
        Uri.parse('${context['origin']}/api/notifications/devices'),
        headers: {
          'Authorization': 'Bearer ${session['token']}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': endpoint.url,
          'registrationId': registrationId,
        }),
      );
      return;
    }
    await _writeContext({
      ...context,
      'token': endpoint.url,
      'provider': 'unifiedpush',
      'registrationId': registrationId,
    });
    PushNotificationService.instance.status.value = 'Đã đăng ký UnifiedPush';
  } catch (e) {
    PushNotificationService.instance.status.value = e.toString();
  }
}

Future<void> _revoked(String instance) async {
  if ((await _pushContext())?['instance'] != instance) return;
  await PushNotificationService.instance.unregister();
  PushNotificationService.instance.status.value =
      'Endpoint đã bị thu hồi. Chọn đăng ký lại.';
}

Future<void> _receive(PushMessage message, String instance) async {
  if (!message.decrypted) return;
  try {
    final context = await _pushContext();
    final payload = jsonDecode(utf8.decode(message.content)) as Map;
    final session = await LocalSession.store.read();
    if (context == null ||
        context['instance'] != instance ||
        !storedSessionMatchesContext(session, context) ||
        !pushMatchesContext(payload, context))
      return;
    WorkflowRefreshService.instance.refreshAll();
    await _local.show(
      id: (payload['notificationId'] as String).hashCode & 0x7fffffff,
      title: 'Công việc',
      body: 'Có cập nhật công việc. Mở ứng dụng để xem.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'workflow',
          'Công việc',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(payload),
    );
  } catch (_) {}
}

class PushNotificationService with WidgetsBindingObserver {
  static final instance = PushNotificationService();
  final status = ValueNotifier<String>('Chưa đăng ký push');
  Map<String, dynamic>? config;
  GlobalKey<NavigatorState>? _navigator;
  Map? _pending;
  bool _started = false, _opening = false;
  Future<void> _syncing = Future.value();
  String? _apnsToken;
  Future<void> start(GlobalKey<NavigatorState> navigator) async {
    _navigator = navigator;
    if (_started ||
        kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform))
      return;
    try {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      LocalSession.changes.addListener(_changed);
      ApiConfig.changes.addListener(_changed);
      LocalSession.beforeLogout.add(_logout);
      if (defaultTargetPlatform == TargetPlatform.android) {
        final launch = await _local.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true &&
            launch?.notificationResponse?.payload != null)
          open(jsonDecode(launch!.notificationResponse!.payload!) as Map);
      } else {
        _apns.setMethodCallHandler((call) async {
          if (call.method == 'token') {
            _apnsToken = call.arguments as String;
            _changed();
          }
          if (call.method == 'opened') open(call.arguments as Map);
          if (call.method == 'foreground') {
            final context = await _pushContext();
            if (context != null &&
                pushMatchesContext(call.arguments as Map, context) &&
                LocalSession.isLoggedIn) {
              WorkflowRefreshService.instance.refreshAll();
              final navigator = _navigator?.currentState;
              if (navigator != null && navigator.mounted)
                ScaffoldMessenger.of(navigator.context).showSnackBar(
                  SnackBar(
                    content: const Text('Có cập nhật công việc'),
                    action: SnackBarAction(
                      label: 'Xem',
                      onPressed: () => open(call.arguments as Map),
                    ),
                  ),
                );
            }
          }
          if (call.method == 'error')
            status.value = 'APNs: ' + call.arguments.toString();
        });
        final pending = await _apns.invokeMapMethod<String, dynamic>('pending');
        if (pending != null) open(pending);
      }
      _changed();
    } catch (e) {
      status.value = 'Push chưa sẵn sàng: $e';
      stop();
    }
  }

  void _changed() {
    _syncing = _syncing.then((_) => _sync()).catchError((Object e) {
      status.value = 'Push chưa sẵn sàng: $e';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _changed();
  }

  void stop() {
    _started = false;
    LocalSession.changes.removeListener(_changed);
    ApiConfig.changes.removeListener(_changed);
    LocalSession.beforeLogout.remove(_logout);
    WidgetsBinding.instance.removeObserver(this);
    _apns.setMethodCallHandler(null);
  }

  Future<void> unregister() async {
    final context = await _pushContext();
    await (await SharedPreferences.getInstance()).remove(_contextKey);
    if (context == null) return;
    final session = await LocalSession.store.read();
    if (session?['server'] != context['origin'] ||
        context['token'] == null ||
        context['registrationId'] == null)
      return;
    try {
      await http
          .delete(
            Uri.parse('${context['origin']}/api/notifications/devices'),
            headers: {
              'Authorization': 'Bearer ${session!['token']}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Tunnel-Skip-AntiPhishing-Page': 'true',
            },
            body: jsonEncode({
              'token': context['token'],
              'registrationId': context['registrationId'],
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _logout() async {
    final context = await _pushContext();
    await unregister();
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (context?['instance'] != null)
        await UnifiedPush.unregister(context!['instance'] as String);
      await _local.cancelAll();
    } else {
      await _apns.invokeMethod<void>('unregister');
    }
    _pending = null;
    _apnsToken = null;
    config = null;
  }

  Future<void> selectDistributor(String distributor) async {
    await _logout();
    await UnifiedPush.saveDistributor(distributor);
    _changed();
  }

  Future<void> registerAgain() async {
    await _logout();
    _changed();
  }

  Future<void> _sync() async {
    if (!_started) return;
    if (!LocalSession.isLoggedIn) {
      // Session restoration happens after startup; keep its registration until resolved.
      if (await LocalSession.store.read() == null) await _logout();
      return;
    }
    final origin = ApiConfig.origin, user = LocalSession.userId;
    final auth = LocalSession.tokenFor(origin);
    if (auth == null || user == null) return;
    final result = await FarmApi.instance.get('/notifications/push-config');
    if (origin != ApiConfig.origin ||
        user != LocalSession.userId ||
        auth != LocalSession.tokenFor(origin))
      return;
    config = Map<String, dynamic>.from(result['data'] as Map);
    final channels = config!['channels'] as Map;
    final android = defaultTargetPlatform == TargetPlatform.android;
    var context = await _pushContext();
    if (context != null &&
        (context['origin'] != origin ||
            context['user'] != user ||
            context['version'] != config!['version'])) {
      await _logout();
      config = Map<String, dynamic>.from(result['data'] as Map);
      context = null;
    }
    if (channels[android ? 'unifiedpush' : 'apns'] != true) {
      status.value =
          'Kênh push chưa cấu hình. Thông báo trong app vẫn hoạt động.';
      return;
    }
    context ??= {
      'origin': origin,
      'user': user,
      'version': config!['version'],
      'ntfyUrl': config!['ntfyUrl'],
      'instance': DateTime.now().microsecondsSinceEpoch.toString(),
    };
    await _writeContext(context);
    if (android) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      if (!await UnifiedPush.tryUseCurrentOrDefaultDistributor()) {
        status.value = 'Cài ntfy distributor và chọn trong cài đặt thông báo.';
        return;
      }
      await UnifiedPush.register(
        instance: context['instance'] as String,
        vapid: config!['vapidPublicKey'] as String?,
      );
    } else {
      final native = await _apns.invokeMapMethod<String, dynamic>('register');
      if (native?['granted'] != true) {
        status.value = 'Chưa cho phép thông báo APNs';
        return;
      }
      _apnsToken ??= native?['token'] as String?;
      if (_apnsToken == null) {
        status.value = 'Đang chờ APNs token/quyền thông báo';
        return;
      }
      if (_apnsToken != context['token'] || context['registrationId'] == null) {
        final registered = await FarmApi.instance
            .put('/notifications/devices', {
              'platform': 'ios',
              'provider': 'apns',
              'token': _apnsToken,
              'apnsEnvironment': native?['environment'] ?? 'production',
            });
        if (origin != ApiConfig.origin ||
            user != LocalSession.userId ||
            auth != LocalSession.tokenFor(origin)) {
          await http.delete(
            Uri.parse('$origin/api/notifications/devices'),
            headers: {
              'Authorization': 'Bearer $auth',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': _apnsToken,
              'registrationId': (registered['data'] as Map)['registrationId'],
            }),
          );
          return;
        }
        await _writeContext({
          ...context,
          'token': _apnsToken,
          'provider': 'apns',
          'registrationId': (registered['data'] as Map)['registrationId'],
        });
      }
      status.value = 'Đã đăng ký APNs';
    }
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
    final context = await _pushContext();
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
