import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unifiedpush/unifiedpush.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/storage/local_session.dart';

class PushSettingsCard extends StatefulWidget {
  const PushSettingsCard({super.key});
  @override
  State<PushSettingsCard> createState() => _PushSettingsCardState();
}

class _PushSettingsCardState extends State<PushSettingsCard> {
  Map? _config;
  List<String> _distributors = [];
  String? _selected;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!LocalSession.isLoggedIn) return;
    try {
      final result = await FarmApi.instance.get('/notifications/push-config');
      final android =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final distributors = android
          ? await UnifiedPush.getDistributors()
          : <String>[];
      final selected = android ? await UnifiedPush.getDistributor() : null;
      if (mounted)
        setState(() {
          _config = result['data'] as Map;
          _distributors = distributors;
          _selected = selected;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!LocalSession.isLoggedIn) return const SizedBox.shrink();
    final url = _config?['ntfyUrl'] as String?;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thông báo đẩy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ValueListenableBuilder<String>(
              valueListenable: PushNotificationService.instance.status,
              builder: (_, value, _) => Text(value),
            ),
            if (_error != null) Text(_error!),
            if (url != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Máy chủ ntfy'),
                subtitle: SelectableText(url),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                ),
              ),
            if (android) ...[
              const Text(
                'Cài ứng dụng ntfy hỗ trợ UnifiedPush. Trong ntfy, đặt máy chủ ở URL trên và đăng nhập tài khoản chỉ đọc do admin cấp. Sau đó chọn distributor và đăng ký lại.',
              ),
              if (_distributors.isEmpty)
                const Text(
                  'Chưa tìm thấy distributor. Cài ntfy rồi bấm Tải lại.',
                ),
              if (_distributors.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(_selected),
                  initialValue: _distributors.contains(_selected)
                      ? _selected
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'UnifiedPush distributor',
                  ),
                  items: _distributors
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (d) async {
                    if (d == null) return;
                    await PushNotificationService.instance.selectDistributor(d);
                    await _load();
                  },
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: _load, child: const Text('Tải lại')),
                if (!kIsWeb &&
                    [
                      TargetPlatform.android,
                      TargetPlatform.iOS,
                    ].contains(defaultTargetPlatform))
                  FilledButton(
                    onPressed: () async {
                      await PushNotificationService.instance.registerAgain();
                      await _load();
                    },
                    child: const Text('Đăng ký lại'),
                  ),
              ],
            ),
            const Text(
              'Đổi URL tunnel, khóa VAPID hoặc distributor cần đăng ký lại. Thông báo trong app và tự tải lại vẫn hoạt động khi push chưa bật.',
            ),
          ],
        ),
      ),
    );
  }
}
