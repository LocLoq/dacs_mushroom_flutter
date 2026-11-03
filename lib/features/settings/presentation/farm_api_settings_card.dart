import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/network/mock_config.dart';
import '../../../core/storage/local_session.dart';
import '../../../core/widgets/soft_card.dart';

/// Địa chỉ API Trại nấm (Node, có hậu tố /api). Tách riêng khỏi "Backend URL" của dịch vụ AI.
class FarmApiSettingsCard extends StatefulWidget {
  const FarmApiSettingsCard({super.key});

  @override
  State<FarmApiSettingsCard> createState() => _FarmApiSettingsCardState();
}

class _FarmApiSettingsCardState extends State<FarmApiSettingsCard> {
  late final _ctrl = TextEditingController(text: ApiConfig.baseUrl);
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ApiConfig.save(_ctrl.text);
    if (!mounted) return;
    setState(() {
      _ctrl.text = ApiConfig.baseUrl;
      _msg = 'Đã lưu địa chỉ API.';
      _ok = true;
    });
  }

  /// Máy chủ phản hồi bất kỳ mã HTTP nào (kể cả 401) nghĩa là kết nối được.
  Future<void> _toggleMock(bool on) async {
    await MockConfig.set(on);
    await LocalSession.clear(); // token của chế độ này không dùng được ở chế độ kia
    if (!mounted) return;
    setState(() {
      _ok = true;
      _msg = on
          ? 'Đã bật dữ liệu mẫu. Đăng nhập bằng admin/admin123, manager/manager123 hoặc staff/staff123.'
          : 'Đã tắt dữ liệu mẫu. Ứng dụng sẽ gọi API thật; hãy đăng nhập lại.';
    });
  }

  Future<void> _test() async {
    if (MockConfig.enabled) {
      _result(true, 'Đang dùng dữ liệu mẫu, không gọi máy chủ. Tắt công tắc ở trên để kiểm tra API thật.');
      return;
    }
    await ApiConfig.save(_ctrl.text);
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await FarmApi.instance.get('/auth/me', public: true);
      _result(true, 'Kết nối được máy chủ.');
    } on ApiException catch (e) {
      if (e.status > 0) {
        _result(true, 'Kết nối được máy chủ (HTTP ${e.status}).');
      } else {
        _result(false, e.message);
      }
    }
  }

  void _result(bool ok, String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = ok;
      _msg = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('API Trại nấm'),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: MockConfig.notifier,
                builder: (context, on, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: on,
                  onChanged: _toggleMock,
                  title: const Text('Dùng dữ liệu mẫu'),
                  subtitle: const Text('Không cần backend: đăng nhập và mọi màn quản lý chạy trên dữ liệu giả trong bộ nhớ.'),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Địa chỉ API thật, dùng khi tắt dữ liệu mẫu (khác với máy chủ AI ở trên).',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ API',
                  prefixIcon: Icon(Icons.api_rounded),
                  hintText: 'http://10.0.2.2:8080/api',
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: const LinearProgressIndicator(minHeight: 6)),
              ],
              if (_msg != null) ...[
                const SizedBox(height: 10),
                Text(_msg!, style: TextStyle(color: _ok ? AppColors.success : AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: FilledButton(onPressed: _busy ? null : _test, child: const Text('Lưu và kiểm tra'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: _busy ? null : _save, child: const Text('Chỉ lưu'))),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
