import 'package:flutter_test/flutter_test.dart';
import 'package:thu/core/services/backend_queue_service.dart';

void main() {
  group('BackendQueueService.normalizeBaseUrl tests', () {
    test('normalizes standard http url with port and trailing slash', () {
      expect(
        BackendQueueService.normalizeBaseUrl('http://192.168.1.15:8000/'),
        'http://192.168.1.15:8000',
      );
    });

    test('adds http scheme if missing', () {
      expect(
        BackendQueueService.normalizeBaseUrl('10.0.2.2:8000'),
        'http://10.0.2.2:8000',
      );
    });

    test('strips paths and query params', () {
      expect(
        BackendQueueService.normalizeBaseUrl('http://localhost:8000/api/v1/test?query=123#fragment'),
        'http://localhost:8000',
      );
    });

    test('preserves https scheme', () {
      expect(
        BackendQueueService.normalizeBaseUrl('https://my-backend.com:8443/'),
        'https://my-backend.com:8443',
      );
    });
  });
}

