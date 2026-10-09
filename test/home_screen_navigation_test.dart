import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/app/config/app_constants.dart';
import 'package:thu/app/home_screen.dart';
import 'package:thu/core/storage/local_session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefBackendConfigured: true,
    });
    LocalSession.clear();
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(initialIndex: 2)),
    );
    await tester.pump();
  }

  testWidgets('compact layout opens, closes, and selects from the drawer', (
    tester,
  ) async {
    await pumpHome(tester, const Size(390, 844));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('home-appbar-menu-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-appbar-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-navigation-drawer')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-navigation-drawer')), findsNothing);

    await tester.tap(find.byKey(const Key('home-appbar-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giống nấm'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-navigation-drawer')), findsNothing);
    expect(find.text('Quản Lý Giống Nấm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small compact layout keeps the content full width', (tester) async {
    await pumpHome(tester, const Size(320, 568));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('home-appbar-menu-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet layout starts with a 72 pixel compact rail', (tester) async {
    await pumpHome(tester, const Size(800, 1280));

    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).width, 72);
    expect(find.byTooltip('Mở rộng menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing changes the navigation mode without losing selection', (
    tester,
  ) async {
    await pumpHome(tester, const Size(800, 1280));
    expect(find.text('Quản Lý Cơ Sở Trại Nấm'), findsOneWidget);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('home-appbar-menu-button')), findsOneWidget);
    expect(find.text('Quản Lý Cơ Sở Trại Nấm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop rail toggles without changing the selected content', (
    tester,
  ) async {
    await pumpHome(tester, const Size(1280, 800));

    final rail = find.byType(NavigationRail);
    expect(tester.getSize(rail).width, 220);
    expect(find.text('Quản Lý Cơ Sở Trại Nấm'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-rail-toggle')));
    await tester.pumpAndSettle();

    expect(tester.getSize(rail).width, 72);
    expect(find.text('Quản Lý Cơ Sở Trại Nấm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
