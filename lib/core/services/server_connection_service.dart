import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_config.dart';

enum PushHostMode {
  vps('VPS'),
  lan('Mạng nội bộ'),
  tunnel('VS Code tunnel');

  const PushHostMode(this.label);
  final String label;
  static PushHostMode infer(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.host.endsWith('.devtunnels.ms') == true) return tunnel;
    if (uri != null && uri.host.isNotEmpty && isPrivateHost(uri.host)) return lan;
    return vps;
  }
}

bool isPrivateHost(String host) {
  host = host.toLowerCase();
  if (host == 'localhost' ||
      host == '::1' ||
      host.endsWith('.local') || host.endsWith('.lan') || host.endsWith('.home.arpa') ||
      (!host.contains('.') && !host.contains(':')))
    return true;
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length == 4 &&
      parts.every((n) => n != null && n >= 0 && n <= 255)) {
    final a = parts[0]!, b = parts[1]!;
    return a == 10 ||
        a == 127 ||
        a == 192 && b == 168 ||
        a == 172 && b >= 16 && b <= 31 ||
        a == 169 && b == 254;
  }
  return host.contains(':') && RegExp(r'^(fc|fd|fe[89ab])').hasMatch(host);
}

String validateServerUrl(String input, PushHostMode mode) {
  if (input.trim().isEmpty)
    throw const FormatException('Vui lòng nhập địa chỉ máy chủ.');
  final normalized = input.contains('://')
      ? input
      : '${mode == PushHostMode.lan ? 'http' : 'https'}://$input';
  final uri = Uri.parse(normalized.trim());
  if (uri.fragment.isNotEmpty ||
      uri.query.isNotEmpty ||
      !['', '/', '/api', '/api/'].contains(uri.path))
    throw const FormatException('Địa chỉ chỉ gồm origin hoặc /api.');
  final config = ApiConfig.fromInput(normalized);
  if (config.serverOrigin.scheme != 'https' && mode != PushHostMode.lan)
    throw const FormatException('VPS và VS Code tunnel yêu cầu HTTPS.');
  if (mode == PushHostMode.lan && !isPrivateHost(config.serverOrigin.host))
    throw const FormatException('LAN yêu cầu IP nội bộ hoặc tên máy nội bộ.');
  return config.serverOrigin.toString();
}

Future<void> checkServerConnection(String origin) async {
  final response = await http
      .get(
        Uri.parse('$origin/api/test'),
        headers: {
          'Accept': 'application/json',
          'X-Tunnel-Skip-AntiPhishing-Page': 'true',
        },
      )
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200 ||
      !response.headers['content-type'].toString().contains('application/json'))
    throw StateError(
      'API không trả JSON. Kiểm tra URL và port Public của tunnel.',
    );
  final body = jsonDecode(response.body);
  if (body is! Map || body['status'] != 'running')
    throw StateError('API chưa sẵn sàng.');
  final connected = Completer<void>();
  final socket = io.io(
    origin,
    io.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .disableReconnection()
        .disableAutoConnect()
        .setExtraHeaders({
          'Accept': 'application/json',
          'X-Tunnel-Skip-AntiPhishing-Page': 'true',
        })
        .build(),
  );
  socket.onConnect((_) {
    if (!connected.isCompleted) connected.complete();
  });
  socket.onConnectError((error) {
    if (!connected.isCompleted)
      connected.completeError(StateError('Socket.IO: $error'));
  });
  try {
    socket.connect();
    await connected.future.timeout(const Duration(seconds: 8));
  } finally {
    socket.dispose();
  }
}
