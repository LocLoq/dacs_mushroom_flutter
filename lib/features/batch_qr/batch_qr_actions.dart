import 'package:flutter/material.dart';
import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../batches/batch_detail_screen.dart';
import 'batch_qr_scanner_screen.dart';

Future<void> scanBatchForUpdate(BuildContext context) async {
  if (!LocalSession.isLoggedIn) {
    toast(context, 'Đăng nhập để cập nhật lô.', error: true);
    return;
  }
  final code = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const BatchQrScannerScreen()),
  );
  if (code == null || !context.mounted) return;
  if (!LocalSession.isLoggedIn) {
    toast(context, 'Phiên đăng nhập đã kết thúc.', error: true);
    return;
  }
  try {
    final data = (await FarmApi.instance.get(
      '/cultivation-batches/by-code/${Uri.encodeComponent(code)}',
    )).m('data');
    if (!context.mounted || !LocalSession.isLoggedIn || data == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Cập nhật lô ${data.s('batchCode')}',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
          ),
          for (final entry in const {
            'progress': 'Sinh trưởng',
            'care': 'Chăm sóc',
            'harvest': 'Thu hoạch',
          }.entries)
            ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx, entry.key),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted || !LocalSession.isLoggedIn) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BatchDetailScreen(batchId: data.i('id')!, initialTab: action),
      ),
    );
  } on ApiException catch (error) {
    if (context.mounted)
      toast(
        context,
        error.status == 404 ? 'Không tìm thấy lô "$code".' : error.message,
        error: true,
      );
  }
}
