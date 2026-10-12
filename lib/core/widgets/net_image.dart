import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../network/api_config.dart';
import '../storage/local_session.dart';

/// Backend media is fetched as bytes, including on Web, so private images can
/// receive Authorization without relying on browser image-element headers.
class NetImage extends StatefulWidget {
  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
    this.zoomable = true,
    this.authenticated = true,
    this.client,
  });
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final bool zoomable;
  final bool authenticated;
  final http.Client? client;

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  MemoryImage? _provider;
  bool _loading = false;
  bool _error = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    LocalSession.changes.addListener(_reload);
    ApiConfig.changes.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(NetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.authenticated != widget.authenticated ||
        oldWidget.client != widget.client)
      _reload();
  }

  void _clearProvider() {
    final old = _provider;
    _provider = null;
    if (old != null) unawaited(old.evict());
  }

  void _reload() {
    final generation = ++_generation;
    _clearProvider();
    final full = ApiConfig.media(widget.url);
    final uri = full == null ? null : Uri.tryParse(full);
    final ownOrigin = uri?.origin == ApiConfig.origin;
    _loading = ownOrigin && full != null;
    _error = false;
    if (mounted) setState(() {});
    if (_loading) unawaited(_fetch(uri!, generation));
  }

  Future<void> _fetch(Uri uri, int generation) async {
    final client = widget.client ?? http.Client();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final token = widget.authenticated
          ? LocalSession.tokenFor(uri.origin)
          : null;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 30));
      if (!mounted || generation != _generation) return;
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !(response.headers['content-type'] ?? '').startsWith('image/'))
        throw const FormatException('Invalid image response');
      final bytes = Uint8List.fromList(response.bodyBytes);
      setState(() {
        _provider = MemoryImage(bytes);
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _error = true;
          _loading = false;
        });
    } finally {
      if (widget.client == null) client.close();
    }
  }

  @override
  void dispose() {
    _generation++;
    LocalSession.changes.removeListener(_reload);
    ApiConfig.changes.removeListener(_reload);
    _clearProvider();
    super.dispose();
  }

  Widget _placeholder(BuildContext context) => Container(
    width: widget.width,
    height: widget.height,
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(
      _error ? Icons.broken_image_outlined : Icons.image_outlined,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final full = ApiConfig.media(widget.url);
    final ownOrigin =
        full != null && Uri.parse(full).origin == ApiConfig.origin;
    final image = full == null || _loading || (ownOrigin && _provider == null)
        ? _placeholder(context)
        : ownOrigin
        ? Image(
            image: _provider!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, error, stack) => _placeholder(context),
          )
        : Image.network(
            full,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : _placeholder(ctx),
            errorBuilder: (_, error, stack) => _placeholder(context),
          );
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: image,
    );
    if (!widget.zoomable || full == null || _loading || _error) return child;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: NetImage(
                  widget.url,
                  fit: BoxFit.contain,
                  radius: 0,
                  zoomable: false,
                  authenticated: widget.authenticated,
                  client: widget.client,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}
