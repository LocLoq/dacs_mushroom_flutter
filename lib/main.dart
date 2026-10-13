import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/push_notification_service.dart';

@pragma("vm:entry-point")
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await initializeUnifiedPush(); } catch (_) {
    debugPrint("UnifiedPush initialization unavailable");
  }
  if (args.contains('--unifiedpush-bg')) return;
  runApp(const MushroomApp());
}
