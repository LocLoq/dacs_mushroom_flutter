String normalizeBatchCode(String value) {
  final code = value.trim();
  if (code.isEmpty || code.length > 191) {
    throw const FormatException('Mã lô phải dài từ 1 đến 191 ký tự.');
  }
  return code;
}

String batchQrFilename(String code) {
  final safe = normalizeBatchCode(code)
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[ .]+$'), '');
  return 'qr-lo-${safe.isEmpty ? 'batch' : safe}';
}
