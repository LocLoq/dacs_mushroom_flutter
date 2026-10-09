import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/app/app.dart';

void main() {
  testWidgets('App smoke test: mounts MushroomApp without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MushroomApp());
    await tester.pump();
  });
}
