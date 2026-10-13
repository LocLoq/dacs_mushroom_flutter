import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thu/app/config/app_constants.dart';
import 'package:thu/core/services/server_connection_service.dart';
import 'package:thu/core/services/app_preferences_service.dart';
import 'package:thu/core/services/push_notification_service.dart';
import 'package:thu/core/storage/local_session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalSession.clear();
  });
  test(
    'new install requires a VPS URL; existing LAN and tunnel URLs are inferred',
    () async {
      expect(await AppPreferencesService.instance.hostMode(), PushHostMode.vps);
      expect(
        await AppPreferencesService.instance.urlForMode(PushHostMode.vps),
        '',
      );
      expect(
        () => validateServerUrl('', PushHostMode.vps),
        throwsFormatException,
      );
      SharedPreferences.setMockInitialValues({
        AppConstants.prefBackendBaseUrl: 'http://192.168.1.8:8080',
      });
      expect(await AppPreferencesService.instance.hostMode(), PushHostMode.lan);
      expect(
        await AppPreferencesService.instance.urlForMode(PushHostMode.lan),
        'http://192.168.1.8:8080',
      );
      expect(
        PushHostMode.infer('https://app-8080.eu.devtunnels.ms'),
        PushHostMode.tunnel,
      );
    },
  );
  test('VPS/tunnel enforce HTTPS and LAN allows only local hosts', () {
    for (final mode in [PushHostMode.vps, PushHostMode.tunnel]) {
      expect(
        () => validateServerUrl('http://192.168.1.10:8080', mode),
        throwsFormatException,
      );
      expect(
        validateServerUrl('https://api.example.test/api', mode),
        'https://api.example.test',
      );
    }
    for (final url in [
      'http://192.168.1.10:8080',
      'http://10.0.2.2:8080',
      'http://server.local:8080',
      'http://server:8080',
      'http://[fd00::1]:8080',
    ]) {
      expect(validateServerUrl(url, PushHostMode.lan), url);
    }
    for (final url in [
      'http://8.8.8.8',
      'http://public.example.test',
      'https://api.example.test/path',
      'https://user:pass@api.example.test',
    ]) {
      expect(
        () => validateServerUrl(url, PushHostMode.lan),
        throwsFormatException,
      );
    }
  });
  test('profile URLs remain separate and switching origin logs out', () async {
    final service = AppPreferencesService.instance;
    await service.saveServerProfile(
      PushHostMode.lan,
      'http://192.168.1.10:8080',
    );
    LocalSession.save('old-token', {
      'id': 3,
      'role': 'staff',
    }, serverOrigin: 'http://192.168.1.10:8080');
    await service.saveServerProfile(
      PushHostMode.vps,
      'https://api.example.test',
    );
    expect(LocalSession.isLoggedIn, false);
    expect(
      await service.urlForMode(PushHostMode.lan),
      'http://192.168.1.10:8080',
    );
    expect(
      await service.urlForMode(PushHostMode.vps),
      'https://api.example.test',
    );
    expect(await service.hostMode(), PushHostMode.vps);
  });
  test(
    'headless reception checks the secure session account as well as the server',
    () {
      String token(int id) =>
          'header.' +
          base64Url.encode(utf8.encode(jsonEncode({'id': id}))) +
          '.signature';
      final context = {'user': 3, 'origin': 'https://api.example.test'};
      expect(
        storedSessionMatchesContext({
          'server': 'https://api.example.test',
          'token': token(3),
        }, context),
        true,
      );
      expect(
        storedSessionMatchesContext({
          'server': 'https://api.example.test',
          'token': token(4),
        }, context),
        false,
      );
      expect(
        storedSessionMatchesContext({
          'server': 'https://old.example.test',
          'token': token(3),
        }, context),
        false,
      );
      expect(storedSessionMatchesContext(null, context), false);
    },
  );
  test('push from an old account, origin or registration is rejected', () {
    final context = {
      'user': 3,
      'origin': 'https://api.example.test',
      'registrationId': 'new',
    };
    final payload = {
      'userId': '3',
      'origin': 'https://api.example.test',
      'registrationId': 'new',
    };
    expect(pushMatchesContext(payload, context), true);
    expect(pushMatchesContext({...payload, 'userId': '4'}, context), false);
    expect(
      pushMatchesContext({
        ...payload,
        'origin': 'https://other.example.test',
      }, context),
      false,
    );
    expect(
      pushMatchesContext({...payload, 'registrationId': 'old'}, context),
      false,
    );
  });
}
