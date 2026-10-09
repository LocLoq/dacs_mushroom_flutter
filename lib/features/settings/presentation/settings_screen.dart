import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/services/backend_queue_service.dart';
import '../../../core/widgets/soft_card.dart';
import 'farm_api_settings_card.dart';
import '../../recognition/data/queue_event.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool>? onThemeModeChanged;
  final ValueChanged<AppLanguage>? onLanguageChanged;

  /// true khi hiển thị như một tab của Home (không có nút quay lại).
  final bool embedded;

  const SettingsScreen({
    super.key,
    this.onThemeModeChanged,
    this.onLanguageChanged,
    this.embedded = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = AppPreferencesService.instance;
  final _queue = BackendQueueService.instance;
  late final TextEditingController _urlCtrl;

  bool _darkMode = false;
  AppLanguage _language = AppLanguage.vi;
  bool _connecting = false;
  final List<QueueEvent> _logs = [];
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: _queue.backendBaseUrl);
    _loadConfig();
    _logSub = _queue.events.listen((e) {
      if (mounted) {
        setState(() {
          _logs.insert(0, e);
          if (_logs.length > 20) _logs.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _logSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final cfg = await _prefs.load();
    if (mounted) {
      setState(() {
        _darkMode = cfg.darkMode;
        _language = cfg.language;
        _urlCtrl.text = cfg.backendBaseUrl;
      });
    }
  }

  Future<void> _saveUrlOnly() async {
    try {
      final normalized = BackendQueueService.normalizeBaseUrl(_urlCtrl.text);
      await _prefs.saveBackendBaseUrl(normalized);
      _queue.updateBackendBaseUrl(normalized);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, vi: 'Đã lưu cấu hình URL backend: $normalized', en: 'Backend URL saved: $normalized'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }


  Future<void> _connectWs() async {
    setState(() => _connecting = true);
    try {
      final normalized = BackendQueueService.normalizeBaseUrl(_urlCtrl.text);
      await _prefs.saveBackendBaseUrl(normalized);
      await _queue.reconnectWithTimeout(
        normalized,
        timeout: const Duration(seconds: 5),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, vi: 'Kết nối WebSocket thành công!', en: 'WebSocket connected successfully!'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, vi: 'Không kết nối được: $e', en: 'Connection failed: $e'),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnectWs() async {
    await _queue.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, vi: 'Đã ngắt kết nối WebSocket', en: 'WebSocket disconnected'),
          ),
        ),
      );
    }
  }

  void _sendPing() {
    _queue.sendPing();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(context, vi: 'Đã gửi gói tin ping...', en: 'Ping sent...'),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await _prefs.saveDarkMode(value);
    widget.onThemeModeChanged?.call(value);
    if (mounted) {
      AppTextScope.maybeOf(context)?.onThemeModeChanged?.call(value);
    }
  }

  Future<void> _changeLanguage(AppLanguage lang) async {
    setState(() => _language = lang);
    await _prefs.saveLanguage(lang);
    widget.onLanguageChanged?.call(lang);
    if (mounted) {
      AppTextScope.maybeOf(context)?.onLanguageChanged?.call(lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWs = _queue.isWebSocketConnected;
    final wsColor = isWs ? AppColors.success : AppColors.danger;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(widget.embedded ? 20 : 8, 12, 20, 24),
          children: [
            Row(
              children: [
                if (!widget.embedded)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Text(
                  tr(context, vi: 'Cài đặt', en: 'Settings'),
                  style: theme.textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Máy chủ ──
            SectionTitle(tr(context, vi: 'Máy chủ AI', en: 'AI server')),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: wsColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isWs
                            ? tr(context, vi: 'Đã kết nối WebSocket', en: 'WebSocket connected')
                            : tr(context, vi: 'Chưa kết nối WebSocket', en: 'WebSocket disconnected'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: wsColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      labelText: tr(context, vi: 'Địa chỉ Backend URL', en: 'Backend Base URL'),
                      prefixIcon: const Icon(Icons.dns_outlined),
                      hintText: 'http://10.0.2.2:8000',
                    ),
                  ),
                  if (_connecting) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(minHeight: 6),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _connecting ? null : _connectWs,
                          child: Text(tr(context, vi: 'Kết nối', en: 'Connect')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveUrlOnly,
                          child: Text(tr(context, vi: 'Lưu URL', en: 'Save URL')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: isWs ? _disconnectWs : null,
                          icon: const Icon(Icons.link_off_rounded, size: 18),
                          label: Text(tr(context, vi: 'Ngắt kết nối', en: 'Disconnect')),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: isWs ? _sendPing : null,
                          icon: const Icon(Icons.network_ping_rounded, size: 18),
                          label: const Text('Ping'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── API Trại nấm ──
            const FarmApiSettingsCard(),
            const SizedBox(height: 20),

            // ── Giao diện ──
            SectionTitle(tr(context, vi: 'Giao diện', en: 'Appearance')),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: const IconTile(Icons.dark_mode_rounded, size: 40),
                    title: Text(tr(context, vi: 'Chế độ tối', en: 'Dark mode'),
                        style: theme.textTheme.titleSmall),
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const IconTile(Icons.language_rounded, size: 40),
                    title: Text(tr(context, vi: 'Ngôn ngữ', en: 'Language'),
                        style: theme.textTheme.titleSmall),
                    trailing: SegmentedButton<AppLanguage>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: AppLanguage.vi, label: Text('VI')),
                        ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                      ],
                      selected: {_language},
                      onSelectionChanged: (set) => _changeLanguage(set.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Nhật ký ──
            SectionTitle(tr(context, vi: 'Nhật ký WebSocket', en: 'WebSocket log')),
            Container(
              height: 160,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1A0B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        tr(context, vi: 'Chưa có sự kiện nào.', en: 'No events yet.'),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) {
                        final item = _logs[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '[${item.event}] ${item.data}',
                            style: const TextStyle(
                              color: Color(0xFFA6E36B),
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),

            // ── Giới thiệu & khuyến cáo ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.warning.withValues(alpha: 0.14)
                    : AppColors.warningSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.warning),
                      const SizedBox(width: 8),
                      Text(
                        tr(context, vi: 'Về ứng dụng', en: 'About'),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      vi: 'Ứng dụng quản lý sản xuất nấm tích hợp AI nhận diện nấm bằng học sâu (Deep Learning), từ ảnh tĩnh hoặc khung hình tốt nhất trích từ video.',
                      en: 'Mushroom production management with a deep-learning recogniser that works from still photos or the best frame extracted from video.',
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      vi: 'Lưu ý: không tự ý ăn hoặc chế biến nấm hoang dã dựa trên kết quả AI. Kết quả chỉ phục vụ tham khảo và nghiên cứu.',
                      en: 'Notice: never eat or cook wild mushrooms based on AI predictions. Results are for reference and research only.',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
