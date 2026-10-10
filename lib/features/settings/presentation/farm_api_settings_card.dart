import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/network/api_client.dart' as live;
import '../../../core/network/mock_config.dart';
import '../../../core/services/backend_queue_service.dart';
import '../../../core/widgets/soft_card.dart';

class FarmApiSettingsCard extends StatefulWidget {
  const FarmApiSettingsCard({super.key});
  @override
  State<FarmApiSettingsCard> createState() => _FarmApiSettingsCardState();
}

class _FarmApiSettingsCardState extends State<FarmApiSettingsCard> {
  late final _ctrl = TextEditingController(text: ApiConfig.baseUrl);
  bool _busy = false, _ok = false;
  String? _message;
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save({bool check = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ApiConfig.save(_ctrl.text);
      if (check) {
        final response = await live.ApiClient().request(
          '/test',
          auth: live.RequestAuth.none,
        );
        if (response['status'] != 'running')
          throw const ApiException(
            500,
            'Máy chủ trả về phản hồi không phù hợp.',
          );
      }
      if (mounted)
        setState(() {
          _ok = true;
          _ctrl.text = ApiConfig.baseUrl;
          _message = check
              ? 'Kết nối máy chủ thành công.'
              : 'Đã lưu địa chỉ máy chủ.';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _ok = false;
          _message = error.toString();
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleMock(bool value) async {
    setState(() => _busy = true);
    try {
      await MockConfig.set(value);
      await BackendQueueService.instance.disconnect();
      BackendQueueService.instance.clearSessionJobs();
      if (!value) await BackendQueueService.instance.connect();
      if (mounted)
        setState(() {
          _ok = true;
          _message = value
              ? 'Đã bật dữ liệu mẫu. Đăng nhập bằng admin/admin123, manager/manager123 hoặc staff/staff123.'
              : 'Đã bật API thật. Vui lòng đăng nhập lại.';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _ok = false;
          _message = error.toString();
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle('Máy chủ quản lý và nhận diện'),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: MockConfig.notifier,
              builder: (context, value, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: value,
                onChanged: _busy ? null : _toggleMock,
                title: const Text('Dùng dữ liệu mẫu'),
                subtitle: const Text(
                  'Dùng thử khi không có máy chủ. Dữ liệu mẫu tách biệt với dữ liệu thật.',
                ),
              ),
            ),
            const Divider(),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ API',
                prefixIcon: Icon(Icons.api_rounded),
                hintText: 'http://10.0.2.2:8080/api',
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _ok ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(check: true),
                    child: const Text('Lưu và kiểm tra'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('Chỉ lưu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
