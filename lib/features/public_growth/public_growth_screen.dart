import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/mushroom_glyph.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';

/// Tra cứu tiến trình lô công khai (specs/S16_PUBLIC_GROWTH.md). Không cần đăng nhập
/// và LUÔN bỏ header Authorization, kể cả khi đang có phiên.
class PublicGrowthScreen extends StatefulWidget {
  final String? initialCode;

  const PublicGrowthScreen({super.key, this.initialCode});

  @override
  State<PublicGrowthScreen> createState() => _PublicGrowthScreenState();
}

enum _St { idle, loading, notFound, error, done }

class _PublicGrowthScreenState extends State<PublicGrowthScreen> {
  final _ctrl = TextEditingController();
  _St _st = _St.idle; // "chưa tra" khác "không thấy lô" khác "lỗi mạng"
  String _msg = '';
  J? _data;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      _ctrl.text = widget.initialCode!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty || code.length > 191) {
      setState(() {
        _st = _St.error;
        _msg = 'Mã lô phải dài từ 1 đến 191 ký tự.';
      });
      return; // không gọi API
    }
    final my = ++_ticket;
    setState(() => _st = _St.loading);
    try {
      final r = await FarmApi.instance.get(
        '/public/cultivation-batches/${Uri.encodeComponent(code)}/growth-progress/current',
        public: true,
      );
      if (!mounted || my != _ticket) return; // bỏ phản hồi của lượt tra trước đến muộn
      setState(() {
        _data = r.m('data');
        _st = _St.done;
      });
    } on ApiException catch (e) {
      if (!mounted || my != _ticket) return;
      setState(() {
        _st = e.status == 404 ? _St.notFound : _St.error;
        _msg = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tra cứu tiến trình lô')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text('Nhập mã lô in trên bao bì để xem giai đoạn sinh trưởng mới nhất.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (_) {
              // Sửa input thì bỏ kết quả cũ.
              if (_st == _St.done || _st == _St.notFound) setState(() => _st = _St.idle);
            },
            decoration: InputDecoration(
              hintText: 'Ví dụ: LO-2026-001',
              prefixIcon: const Icon(Icons.qr_code_2_rounded),
              suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search_rounded)),
            ),
          ),
          const SizedBox(height: 16),
          if (_st == _St.idle)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: MushroomGlyph(size: 90)),
            ),
          if (_st == _St.loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (_st == _St.notFound)
            _notice(Icons.search_off_rounded, 'Không tìm thấy lô "${_ctrl.text.trim()}". Kiểm tra lại mã.'),
          if (_st == _St.error) _notice(Icons.error_outline_rounded, _msg, danger: true),
          if (_st == _St.done && _data != null) _result(context, _data!),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String text, {bool danger = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: danger ? AppColors.dangerSoft : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: danger ? AppColors.danger : null),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: danger ? AppColors.danger : null))),
        ]),
      );

  /// Chỉ hiển thị phần whitelist công khai: không nhân viên, chi phí, submissions…
  Widget _result(BuildContext context, J d) {
    final theme = Theme.of(context);
    final st = d.sn('status');
    final cur = d.m('currentProgress');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(d.s('batchCode'), style: theme.textTheme.titleLarge)),
            StatusChip(text: label(batchStatusLabels, st), color: statusColor(st)),
          ]),
          const SizedBox(height: 6),
          InfoRow('Giống nấm', d.m('mushroom')?.s('commonName')),
          InfoRow('Tên khoa học', d.m('mushroom')?.s('scientificName')),
          InfoRow('Cơ sở', d.m('facility')?.s('name')),
          InfoRow('Tỉnh/Thành', d.m('facility')?.sn('province')),
          InfoRow('Ngày bắt đầu', fmtDate(d.sn('startDate'))),
          InfoRow('Dự kiến thu hoạch', fmtDate(d.sn('expectedHarvestDate'))),
        ]),
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: cur == null
            // Lô chưa có nhật ký: khác 404 và khác lỗi mạng.
            ? Text('Lô này chưa có nhật ký sinh trưởng.', style: theme.textTheme.bodyMedium)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Giai đoạn hiện tại', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(cur.s('stage'), style: theme.textTheme.titleLarge),
                Text(fmtDateTime(cur.sn('recordedAt')), style: theme.textTheme.bodySmall),
                if (cur.sn('notes') != null) ...[const SizedBox(height: 8), Text(cur.s('notes'))],
                if (cur.l('images').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final img in cur.l('images')) NetImage(img.sn('imageUrl'), width: 96, height: 96),
                  ]),
                ],
              ]),
      ),
    ]);
  }
}
