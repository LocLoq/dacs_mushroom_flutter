import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../audit/audit_log_screen.dart';

/// Lịch sử nhận diện trên máy chủ — manager/admin (specs/S11_CLASSIFIER_HISTORY.md).
/// Backend KHÔNG lưu ảnh đầu vào nên không có thumbnail.
class ServerHistoryView extends StatefulWidget {
  const ServerHistoryView({super.key});

  @override
  State<ServerHistoryView> createState() => _ServerHistoryViewState();
}

class _ServerHistoryViewState extends State<ServerHistoryView> {
  String? _status;
  DateTime? _from;
  DateTime? _to;

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: (from ? _from : _to) ?? now, firstDate: DateTime(2020), lastDate: DateTime(now.year + 1));
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bad = _from != null && _to != null && _from!.isAfter(_to!);
    return PagedListView(
      searchHint: 'Tìm theo tên dự đoán',
      deps: [_status, _from, _to],
      emptyText: 'Chưa có lượt nhận diện nào trên máy chủ.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ChoiceChip(label: const Text('Tất cả'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
          for (final e in classifierStatusLabels.entries)
            ChoiceChip(label: Text(e.value), selected: _status == e.key, onSelected: (_) => setState(() => _status = e.key)),
          ActionChip(
              avatar: const Icon(Icons.event_rounded, size: 16),
              label: Text(_from == null ? 'Từ ngày' : fmtDate(_from!.toIso8601String())),
              onPressed: () => _pickDate(true)),
          ActionChip(
              avatar: const Icon(Icons.event_rounded, size: 16),
              label: Text(_to == null ? 'Đến ngày' : fmtDate(_to!.toIso8601String())),
              onPressed: () => _pickDate(false)),
          if (bad) Text('Từ ngày phải ≤ Đến ngày', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        ]),
      ),
      fetch: (p, s) async {
        if (bad) return PageData.empty;
        return PageData.from(await FarmApi.instance.get('/mushroom-classifier/history', query: {
          'page': p,
          'limit': 20,
          'predictedName': s, // search UI dùng predictedName
          'status': _status,
          'from': _from == null ? null : startOfDayIso(_from!),
          'to': _to == null ? null : endOfDayIso(_to!),
        }));
      },
      itemBuilder: (ctx, r, _) {
        final st = r.sn('status');
        return SoftCard(
          padding: const EdgeInsets.all(12),
          onTap: () => showDialog(context: context, builder: (_) => _HistoryDetail(id: r.s('id'))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.sn('predictedName') ?? 'Chưa có kết quả', style: theme.textTheme.titleSmall)),
              StatusChip(text: label(classifierStatusLabels, st), color: statusColor(st)),
            ]),
            const SizedBox(height: 4),
            Text('${r.s('originalName')} · ${pct01(r.d('confidence'))}', style: theme.textTheme.bodySmall),
            Text(fmtDateTime(r.sn('createdAt')), style: theme.textTheme.bodySmall),
          ]),
        );
      },
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  final String id; // UUID

  const _HistoryDetail({required this.id});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.of(context).size.height * 0.8),
        // GET detail riêng; lỗi detail không xoá danh sách.
        child: FutureBody<J>(
          load: () async => (await FarmApi.instance.get('/mushroom-classifier/history/$id')).m('data') ?? {},
          builder: (ctx, d, _) {
            final st = d.sn('status');
            final res = d.m('result');
            return ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
              Row(children: [
                Expanded(child: Text(d.sn('predictedName') ?? 'Chưa có kết quả', style: Theme.of(ctx).textTheme.titleLarge)),
                StatusChip(text: label(classifierStatusLabels, st), color: statusColor(st)),
              ]),
              const SizedBox(height: 8),
              InfoRow('Tên file', d.sn('originalName')),
              InfoRow('Loại / dung lượng', '${d.s('mimeType')} · ${d.i('fileSize') == null ? '—' : '${(d.i('fileSize')! / 1024).toStringAsFixed(0)} KB'}'),
              InfoRow('Độc tính', label(classifierEdibilityLabels, d.sn('edibility'))),
              InfoRow('Độ tin cậy', pct01(d.d('confidence'))),
              InfoRow('Người gửi', d.m('user')?.sn('username')),
              InfoRow('Xếp hàng', fmtDateTime(d.sn('queuedAt'))),
              InfoRow('Hoàn tất', fmtDateTime(d.sn('completedAt'))),
              if (d.sn('errorMessage') != null) InfoRow('Lỗi', d.sn('errorMessage')),
              if (res != null) InfoRow('Tên khoa học', res.sn('scientificName')),
              const SizedBox(height: 8),
              Text('Ảnh đầu vào không được lưu trên máy chủ.', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))),
            ]);
          },
        ),
      ),
    );
  }
}
