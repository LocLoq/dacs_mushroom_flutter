import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_saver/file_saver.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/utils/batch_qr.dart';

Future<void> showBatchQr(BuildContext context, String batchCode) =>
    showDialog<void>(
      context: context,
      builder: (_) => BatchQrDialog(batchCode: normalizeBatchCode(batchCode)),
    );

class BatchQrDialog extends StatefulWidget {
  const BatchQrDialog({super.key, required this.batchCode, this.savePng});
  final String batchCode;
  final Future<String?> Function(String name, Uint8List bytes)? savePng;
  @override
  State<BatchQrDialog> createState() => _BatchQrDialogState();
}

class _BatchQrDialogState extends State<BatchQrDialog> {
  final _imageKey = GlobalKey();
  bool _saving = false;
  String? _message;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Không tạo được ảnh QR.');
      final name = batchQrFilename(widget.batchCode);
      final png = bytes.buffer.asUint8List();
      final saved = widget.savePng != null
          ? await widget.savePng!(name, png)
          : await FileSaver.instance.saveAs(
              name: name,
              bytes: png,
              fileExtension: 'png',
              mimeType: MimeType.png,
            );
      if (mounted && saved != null && saved.isNotEmpty)
        setState(() => _message = 'Đã lưu ảnh QR.');
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Không lưu được ảnh QR. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mã QR của lô'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _imageKey,
            child: Container(
              color: Colors.white,
              width: 280,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: QrImageView(
                      data: widget.batchCode,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.batchCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.download_rounded),
        label: Text(_saving ? 'Đang lưu…' : 'Lưu PNG'),
      ),
    ],
  );
}
