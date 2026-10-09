import 'package:flutter/material.dart';

import '../../../core/storage/local_session.dart';
import '../../server_history/server_history_view.dart';
import 'recognition_history_screen.dart';

/// Tab Lịch sử: "Trên máy này" cho mọi người; thêm "Máy chủ" cho manager/admin.
class HistoryHub extends StatefulWidget {
  const HistoryHub({super.key});

  @override
  State<HistoryHub> createState() => _HistoryHubState();
}

class _HistoryHubState extends State<HistoryHub> {
  bool _server = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalSession.changes,
      builder: (context, _, __) {
        final canServer = LocalSession.canManage;
        final showServer = canServer && _server;
        if (!canServer) {
          return const RecognitionHistoryScreen(embedded: true);
        }
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Trên máy này'), icon: Icon(Icons.phone_android_rounded, size: 18)),
                    ButtonSegment(value: true, label: Text('Máy chủ'), icon: Icon(Icons.cloud_outlined, size: 18)),
                  ],
                  selected: {showServer},
                  onSelectionChanged: (s) => setState(() => _server = s.first),
                ),
              ),
              if (showServer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Lịch sử trên máy chủ', style: Theme.of(context).textTheme.headlineMedium),
                  ),
                ),
              Expanded(child: showServer ? const ServerHistoryView() : const RecognitionHistoryScreen(embedded: true)),
            ],
          ),
        );
      },
    );
  }
}
