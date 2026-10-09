import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';

/// Nhật ký hệ thống, chỉ đọc — manager/admin (specs/S15_AUDIT_LOG.md).
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

/// Bắt đầu/cuối ngày theo giờ LOCAL của thiết bị, đổi sang ISO UTC.
String startOfDayIso(DateTime d) => DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
String endOfDayIso(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toUtc().toIso8601String();

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _action = TextEditingController();
  final _entity = TextEditingController();
  final _status = TextEditingController();
  final _actor = TextEditingController();
  final _entityId = TextEditingController();
  String? _outcome; // SUCCESS | FAILURE
  DateTime? _from;
  DateTime? _to;
  // Giá trị đã áp dụng (chỉ đổi khi bấm Áp dụng / Enter) -> deps.
  String _fAction = '';
  String _fEntity = '';
  String _fStatus = '';
  String _fActor = '';
  String _fEntityId = '';

  @override
  void dispose() {
    _action.dispose();
    _entity.dispose();
    _status.dispose();
    _actor.dispose();
    _entityId.dispose();
    super.dispose();
  }

  void _apply() => setState(() {
        _fAction = _action.text.trim();
        _fEntity = _entity.text.trim();
        _fStatus = _status.text.trim();
        _fActor = _actor.text.trim();
        _fEntityId = _entityId.text.trim();
      });

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (d == null) return;
    setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badRange = _from != null && _to != null && _from!.isAfter(_to!); // from ≤ to
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký hệ thống')),
      body: PagedListView(
        deps: [_outcome, _fAction, _fEntity, _fStatus, _fActor, _fEntityId, _from, _to],
        emptyText: 'Không có bản ghi nào khớp bộ lọc.',
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _action,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(labelText: 'Hành động', isDense: true),
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _entity,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(labelText: 'Đối tượng', isDense: true),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _entityId,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(labelText: 'ID đối tượng', isDense: true),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _actor,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(labelText: 'ID người làm', isDense: true),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _status,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(labelText: 'HTTP', isDense: true),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final e in {null: 'Mọi kết quả', 'SUCCESS': 'Thành công', 'FAILURE': 'Thất bại'}.entries)
                ChoiceChip(label: Text(e.value), selected: _outcome == e.key, onSelected: (_) => setState(() => _outcome = e.key)),
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: 16),
                label: Text(_from == null ? 'Từ ngày' : fmtDate(_from!.toIso8601String())),
                onPressed: () => _pickDate(true),
              ),
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: 16),
                label: Text(_to == null ? 'Đến ngày' : fmtDate(_to!.toIso8601String())),
                onPressed: () => _pickDate(false),
              ),
              if (_from != null || _to != null)
                TextButton(onPressed: () => setState(() { _from = null; _to = null; }), child: const Text('Xóa ngày')),
              FilledButton(onPressed: _apply, style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), child: const Text('Áp dụng')),
            ]),
            if (badRange) Text('"Từ ngày" phải trước hoặc bằng "Đến ngày".', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ]),
        ),
        fetch: (p, s) async {
          if (badRange) return PageData.empty;
          return PageData.from(await FarmApi.instance.get('/admin/audit-logs', query: {
            'page': p,
            'limit': 20,
            'action': _fAction,
            'entityType': _fEntity,
            'statusCode': _fStatus,
            'actorUserId': _fActor,
            'entityId': _fEntityId,
            'outcome': _outcome,
            'from': _from == null ? null : startOfDayIso(_from!),
            'to': _to == null ? null : endOfDayIso(_to!),
          }));
        },
        itemBuilder: (ctx, r, _) {
          final out = r.sn('outcome');
          return SoftCard(
            padding: const EdgeInsets.all(12),
            onTap: () => _detail(r), // dựng từ dòng hiện có, không gọi GET detail
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.s('action'), style: theme.textTheme.titleSmall)),
                StatusChip(text: '${out == 'SUCCESS' ? 'Thành công' : out == 'FAILURE' ? 'Thất bại' : '—'} · ${r.s('statusCode')}', color: statusColor(out)),
              ]),
              const SizedBox(height: 4),
              Text('${r.sn('actorUsername') ?? 'Hệ thống'} · ${r.s('entityType')} ${r.s('entityId')}', style: theme.textTheme.bodySmall),
              Text(fmtDateTime(r.sn('createdAt')), style: theme.textTheme.bodySmall),
            ]),
          );
        },
      ),
    );
  }

  void _detail(J r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.s('action')),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _row('Người thực hiện', r.sn('actorUsername') ?? 'Hệ thống'),
            _row('Vai trò', label(roleLabels, r.sn('actorRole'))),
            _row('Phương thức', r.sn('method')),
            _row('Đường dẫn', r.sn('path')),
            _row('Đối tượng', '${r.s('entityType')} ${r.s('entityId')}'.trim()),
            _row('Kết quả', '${r.s('outcome')} (HTTP ${r.s('statusCode')})'),
            _row('Thời gian xử lý', r.i('durationMs') == null ? null : '${r.i('durationMs')} ms'),
            _row('Thời điểm', fmtDateTime(r.sn('createdAt'))),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  Widget _row(String k, String? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(style: DefaultTextStyle.of(context).style, children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: (v == null || v.isEmpty) ? '—' : v),
          ]),
        ),
      );
}
