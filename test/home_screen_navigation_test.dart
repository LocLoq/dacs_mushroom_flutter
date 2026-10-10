import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/app/home_screen.dart';
import 'package:thu/app/config/app_constants.dart';
import 'package:thu/core/services/backend_queue_service.dart';
import 'package:thu/core/storage/local_session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefBackendConfigured: true,
    });
    LocalSession.clear();
  });
  tearDown(() async {
    await BackendQueueService.instance.disconnect();
  });
  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await BackendQueueService.instance.disconnect();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'compact layout restores the mushroom hero and five bottom destinations',
    (tester) async {
      await pumpHome(tester, const Size(390, 844));
      expect(find.text('Đây là nấm gì?'), findsOneWidget);
      expect(find.text('Từ điển'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
      expect(find.text('Quản lý'), findsOneWidget);
      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.bySemanticsLabel('Quét'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('manage tab presents real login then returns to recognition', (
    tester,
  ) async {
    await pumpHome(tester, const Size(390, 844));
    await tester.tap(find.text('Quản lý'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý trại nấm'), findsOneWidget);
    expect(find.text('Đăng nhập để quản lý'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Quét'));
    await tester.pumpAndSettle();
    expect(find.text('Đây là nấm gì?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('wide layout keeps the restored main destinations accessible', (
    tester,
  ) async {
    await pumpHome(tester, const Size(1280, 800));
    expect(find.text('Đây là nấm gì?'), findsOneWidget);
    await tester.tap(find.text('Quản lý'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý trại nấm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
