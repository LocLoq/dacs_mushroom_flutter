import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/services/backend_queue_service.dart';
import '../../recognition/data/queue_event.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool>? onThemeModeChanged;
  final ValueChanged<AppLanguage>? onLanguageChanged;

  const SettingsScreen({
    super.key,
    this.onThemeModeChanged,
    this.onLanguageChanged,
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
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
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
            backgroundColor: Colors.red,
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
    final isWs = _queue.isWebSocketConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, vi: 'Cài Đặt Hệ Thống', en: 'System Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Backend & Mạng
          Text(
            tr(context, vi: 'Máy chủ Backend & Hàng đợi', en: 'Backend & Queue Server'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isWs ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isWs
                            ? tr(context, vi: 'Trạng thái: ĐÃ KẾT NỐI WS', en: 'Status: WS CONNECTED')
                            : tr(context, vi: 'Trạng thái: CHƯA KẾT NỐI WS', en: 'Status: WS DISCONNECTED'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isWs ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _saveUrlOnly,
                        child: Text(tr(context, vi: 'Lưu URL', en: 'Save URL')),
                      ),
                      FilledButton(
                        onPressed: _connecting ? null : _connectWs,
                        child: Text(tr(context, vi: 'Kết nối WS', en: 'Connect WS')),
                      ),
                      OutlinedButton(
                        onPressed: isWs ? _disconnectWs : null,
                        child: Text(tr(context, vi: 'Ngắt WS', en: 'Disconnect')),
                      ),
                      IconButton.outlined(
                        tooltip: 'Ping',
                        icon: const Icon(Icons.network_ping),
                        onPressed: isWs ? _sendPing : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Giao diện & Tùy chọn
          Text(
            tr(context, vi: 'Tùy chọn giao diện', en: 'Preferences'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(tr(context, vi: 'Chế độ tối (Dark mode)', en: 'Dark mode')),
                  value: _darkMode,
                  onChanged: _toggleDarkMode,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(tr(context, vi: 'Ngôn ngữ hiển thị', en: 'Language')),
                  trailing: SegmentedButton<AppLanguage>(
                    segments: const [
                      ButtonSegment(value: AppLanguage.vi, label: Text('VI')),
                      ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                    ],
                    selected: {_language},
                    onSelectionChanged: (set) {
                      _changeLanguage(set.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Event Log
          Text(
            tr(context, vi: 'Nhật ký sự kiện WebSocket', en: 'WebSocket Event Logs'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(14),
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
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          '[${item.event}] ${item.data}',
                          style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),

          // Section: Giới thiệu & Khuyến cáo an toàn sinh học
          Card(
            color: Colors.amber.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Text(
                        tr(context, vi: 'Thông tin hệ thống', en: 'About System'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      vi: 'Hệ thống Quản lý Sản xuất Nấm & AI Recognizer tích hợp nhận diện mô hình máy học sâu (Deep Learning) từ ảnh tĩnh và trích xuất video tối ưu frame.',
                      en: 'Mushroom Production Management & AI Recognizer integrates deep learning classification from still photos and optimal video frame extraction.',
                    ),
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      vi: 'LƯU Ý: Không tự ý ăn hoặc chế biến nấm hoang dã dựa trên kết quả AI. Kết quả chỉ phục vụ tham khảo kỹ thuật và nghiên cứu.',
                      en: 'NOTICE: Never consume wild mushrooms based on AI predictions. Results are strictly for reference and research.',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
