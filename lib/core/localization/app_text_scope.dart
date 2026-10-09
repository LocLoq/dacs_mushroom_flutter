import 'package:flutter/widgets.dart';
import 'app_language.dart';

class AppTextScope extends InheritedWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage>? onLanguageChanged;
  final bool darkMode;
  final ValueChanged<bool>? onThemeModeChanged;

  const AppTextScope({
    super.key,
    required this.language,
    this.onLanguageChanged,
    this.darkMode = false,
    this.onThemeModeChanged,
    required super.child,
  });

  static AppTextScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppTextScope>();
  }

  static AppTextScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No AppTextScope found in context');
    return scope!;
  }

  String text({required String vi, required String en}) {
    return language == AppLanguage.en ? en : vi;
  }

  @override
  bool updateShouldNotify(AppTextScope oldWidget) {
    return language != oldWidget.language || darkMode != oldWidget.darkMode;
  }
}

String tr(BuildContext context, {required String vi, required String en}) {
  final scope = AppTextScope.maybeOf(context);
  if (scope == null) return vi;
  return scope.text(vi: vi, en: en);
}

