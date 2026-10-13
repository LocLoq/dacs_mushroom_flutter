import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/services/server_connection_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/storage/local_session.dart';

class PushSettingsCard extends StatefulWidget {
  const PushSettingsCard({super.key});
  @override
  State<PushSettingsCard> createState() => _PushSettingsCardState();
}

class _PushSettingsCardState extends State<PushSettingsCard> {
  late final _address = TextEditingController(text: ApiConfig.origin);
  final _focus = FocusNode();
  String? _message;
  bool _busy = false, _dirty = false;
  @override
  void initState() {
    super.initState();
    ApiConfig.changes.addListener(_serverChanged);
  }

  void _serverChanged() {
    if (!mounted || _dirty || _focus.hasFocus || _busy) return;
    setState(() => _address.text = ApiConfig.origin);
  }

  @override
  void dispose() {
    ApiConfig.changes.removeListener(_serverChanged);
    _address.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save({bool check = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final origin = normalizePushServerAddress(_address.text);
      if (check) await checkServerConnection(origin);
      final loggedIn = LocalSession.isLoggedIn,
          changed = origin != ApiConfig.origin;
      await AppPreferencesService.instance.saveServerProfile(
        PushHostMode.infer(origin),
        origin,
      );
      await ApiConfig.save(origin);
      if (mounted)
        setState(() {
          _address.text = origin;
          _dirty = false;
          _message = loggedIn && changed
              ? 'Đã lưu địa chỉ. Đăng nhập lại để đăng ký thông báo trên máy chủ này.'
              : check
              ? 'Đã lưu và kiểm tra kết nối thành công.'
              : 'Đã lưu địa chỉ API và thông báo.';
        });
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkPush() async {
    try {
      final response = await FarmApi.instance.get('/notifications/push-config');
      final enabled =
          ((response['data'] as Map)['channels'] as Map)['fcm'] == true;
      if (mounted)
        setState(
          () => _message = enabled
              ? 'Máy chủ đã bật thông báo đẩy.'
              : 'Máy chủ chưa bật thông báo đẩy.',
        );
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Chưa kiểm tra được kết nối máy chủ.');
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thông báo trên thiết bị',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('push-server-address'),
            controller: _address,
            focusNode: _focus,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            onChanged: (_) => _dirty = true,
            decoration: const InputDecoration(
              labelText: 'IP/URL backend cho API và thông báo',
              hintText: 'http://<IP>:8080',
              prefixIcon: Icon(Icons.notifications_active_outlined),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Địa chỉ này dùng chung với API của ứng dụng. Đổi máy chủ cần đăng nhập lại. FCM vẫn gửi thông báo qua Firebase.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                key: const Key('save-push-address'),
                onPressed: _busy ? null : () => _save(),
                child: const Text('Lưu địa chỉ'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _save(check: true),
                child: const Text('Lưu và kiểm tra'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!),
            ),
          if (LocalSession.isLoggedIn) ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: PushNotificationService.instance.status,
              builder: (_, value, _) => Text(value),
            ),
            const Text(
              'Cho phép thông báo trên điện thoại để nhận cập nhật khi ứng dụng đang đóng.',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _checkPush,
                  child: const Text('Kiểm tra push'),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          PushNotificationService.instance.registerAgain(),
                        ),
                  child: const Text('Đăng ký lại'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
