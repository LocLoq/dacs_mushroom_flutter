import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/app/app.dart';
import 'package:thu/app/config/app_constants.dart';
import 'package:thu/core/services/backend_queue_service.dart';

void main() {
  testWidgets('App smoke test: restored UI mounts without crashing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefBackendConfigured: true,
    });
    await tester.pumpWidget(const MushroomApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await BackendQueueService.instance.disconnect();
    await tester.pump();
  });
}
