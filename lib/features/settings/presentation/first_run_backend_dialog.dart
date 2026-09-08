import 'package:flutter/material.dart';

import '../../../app/config/app_constants.dart';
import '../../../core/localization/app_text_scope.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/services/backend_queue_service.dart';

class FirstRunBackendDialog extends StatefulWidget {
  const FirstRunBackendDialog({super.key});

  static Future<void> checkAndShow(BuildContext context) async {
    final configured = await AppPreferencesService.instance.isBackendConfigured();
    if (!configured && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const FirstRunBackendDialog(),
      );
    }
  }

  @override
  State<FirstRunBackendDialog> createState() => _FirstRunBackendDialogState();
}

class _FirstRunBackendDialogState extends State<FirstRunBackendDialog> {
  late final TextEditingController _urlCtrl;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: BackendQueueService.instance.backendBaseUrl,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    final rawUrl = _urlCtrl.text.trim();
    try {
      final normalized = BackendQueueService.normalizeBaseUrl(rawUrl);
      await AppPreferencesService.instance.saveBackendBaseUrl(normalized);

      await BackendQueueService.instance.reconnectWithTimeout(
        normalized,
        timeout: const Duration(seconds: 5),
      );

      await AppPreferencesService.instance.markBackendConfigured();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = tr(
          context,
          vi: 'Không thể kết nối đến $rawUrl: $e',
          en: 'Failed to connect to $rawUrl: $e',
        );
      });
    }
  }

  Future<void> _skipOfflineDemo() async {
    await AppPreferencesService.instance.markBackendConfigured();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.settings_ethernet, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(context, vi: 'Thiết Lập Máy Chủ Backend', en: 'Backend Server Setup'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                context,
                vi: 'Nhập địa chỉ máy chủ FastAPI (chạy AI và WebSocket hàng đợi):',
                en: 'Enter FastAPI backend server URL (running AI & queue WebSocket):',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                hintText: AppConstants.kDefaultBackendBaseUrl,
                prefixIcon: Icon(Icons.link),
              ),
            ),
            if (_connecting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : _skipOfflineDemo,
          child: Text(
            tr(context, vi: 'Dùng thử Offline', en: 'Use Offline Demo'),
          ),
        ),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child: Text(
            tr(context, vi: 'Lưu & Kết Nối', en: 'Save & Connect'),
          ),
        ),
      ],
    );
  }
}

