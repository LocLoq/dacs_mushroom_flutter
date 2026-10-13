Official unifiedpush_android 3.5.0 from pub.dev (https://pub.dev/packages/unifiedpush_android/versions/3.5.0), Apache-2.0.

Local patch: apply org.jetbrains.kotlin.android in android/build.gradle.kts because this app uses AGP 8.9.1 without built-in Kotlin. Dart/native connector behavior is unchanged. Remove this override after upgrading to a compatible official package/AGP.
