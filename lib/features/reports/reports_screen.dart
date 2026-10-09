import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../batches/batch_detail_screen.dart';
import '../facilities/facility_list_screen.dart';

/// Báo cáo (specs/S12_REPORTS.md) và xuất file (specs/S13_REPORT_EXPORT.md). manager/admin.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

const _groups = {
  'overview': 'Tổng quan',
  'cultivation': 'Nuôi trồng',
  'financial': 'Tài chính',
  'classifier': 'Nhận diện',
  'audit': 'Hoạt động',
};

class _ReportsScreenState extends State<ReportsScreen> {
  String _group = 'overview';
  late DateTime _from = DateTime(DateTime.now().year, 1, 1); // mặc định 01/01 năm nay
  DateTime _to = DateTime.now();
  String _groupBy = 'month';
  J? _facility;
  J? _species;
  String? _status; // enum LÔ, không phải trạng thái nhận diện
  int _page = 1;

  bool get _usesBatchFilters => _group == 'overview' || _group == 'cultivation' || _group == 'financial';
  bool get _usesGroupBy => _group == 'overview' || _group == 'financial';
  bool get _paged => _group != 'overview';

  String? get _rangeError {
    if (_from.isAfter(_to)) return '"Từ ngày" phải trước hoặc bằng "Đến ngày".';
    if (_to.difference(_from).inDays > 5 * 366) return 'Khoảng ngày tối đa 5 năm.';
    return null;
  }

  /// Chỉ gửi filter áp dụng cho nhóm đang xem; xuất file dùng lại đúng bộ lọc này.
  Map<String, dynamic> _filters() => {
        'from': ymd(_from),
        'to': ymd(_to),
        if (_usesBatchFilters) 'facilityId': _facility?['id'],
        if (_usesBatchFilters) 'mushroomId': _species?['id'],
        if (_usesBatchFilters) 'status': _status,
        if (_usesGroupBy) 'groupBy': _groupBy,
      };

  Map<String, dynamic> _query() => {..._filters(), if (_paged) 'page': _page, if (_paged) 'limit': 20};

  String get _sig => '$_group|${_query()}';

  void _setGroup(String g) => setState(() {
        _group = g; // đổi nhóm: giữ filter tương thích, về trang 1
        _page = 1;
      });

  Future<void> _pickDate(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (d == null) return;
    setState(() {
      from ? _from = d : _to = d;
      _page = 1;
    });
  }

  Future<void> _pickRef(bool facility) async {
    final r = await pickOneFrom(context, facility ? facilityPicker() : speciesPicker());
    if (r == null) return; // đóng sheet: giữ bộ lọc cũ
    setState(() {
      final v = r.isEmpty ? null : r.first;
      facility ? _facility = v : _species = v;
      _page = 1;
    });
  }

  // ───────────────────────── Xuất file ─────────────────────────

  Future<void> _export() async {
    String fmt = 'xlsx'; // mặc định XLSX
    bool busy = false;
    String? msg;
    bool err = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Xuất báo cáo'),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Loại: ${_groups[_group]}'),
              Text('Từ ${fmtDate(_from.toIso8601String())} đến ${fmtDate(_to.toIso8601String())}'),
              if (_usesBatchFilters && _facility != null) Text('Cơ sở: ${_facility!.s('label')}'),
              if (_usesBatchFilters && _species != null) Text('Giống: ${_species!.s('label')}'),
              if (_usesBatchFilters && _status != null) Text('Trạng thái lô: ${label(batchStatusLabels, _status)}'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final f in const ['csv', 'xlsx', 'pdf'])
                  ChoiceChip(
                    label: Text(f.toUpperCase()),
                    selected: fmt == f,
                    onSelected: busy ? null : (_) => setS(() => fmt = f),
                  ),
              ]),
              if (busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
              if (msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(msg!, style: TextStyle(color: err ? AppColors.danger : AppColors.success)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Đóng')),
            FilledButton(
              onPressed: busy
                  ? null // chống nhấn đôi
                  : () async {
                      setS(() {
                        busy = true;
                        msg = null;
                      });
                      try {
                        // Không gửi page/limit; server xuất toàn bộ theo bộ lọc.
                        final f = await FarmApi.instance.download('/reports/$_group/export', query: {'format': fmt, ..._filters()});
                        final path = await _save(f, fmt);
                        setS(() {
                          msg = 'Đã lưu: $path';
                          err = false;
                        });
                      } on ApiException catch (e) {
                        setS(() {
                          msg = e.message;
                          err = true;
                        });
                      } catch (e) {
                        setS(() {
                          msg = 'Không lưu được file: $e';
                          err = true;
                        });
                      } finally {
                        setS(() => busy = false);
                      }
                    },
              child: const Text('Tải xuống'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _save(DownloadedFile f, String fmt) async {
    final now = DateTime.now().toUtc();
    var name = f.filename ?? '$_group-report-${ymd(now)}.$fmt';
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (name.isEmpty) name = '$_group-report-${ymd(now)}.$fmt';
    // Android: thư mục ngoài riêng của app (xem được qua trình quản lý file/USB);
    // desktop: thư mục Downloads; iOS và dự phòng: thư mục Documents của app.
    Directory? dir;
    try {
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      }
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(f.bytes, flush: true);
    return file.path;
  }

  // ───────────────────────── Giao diện ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeErr = _rangeError;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo'), actions: [
        IconButton(tooltip: 'Xuất file', onPressed: rangeErr == null ? _export : null, icon: const Icon(Icons.file_download_outlined)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in _groups.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(e.value), selected: _group == e.key, onSelected: (_) => _setGroup(e.key)),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ActionChip(avatar: const Icon(Icons.event_rounded, size: 16), label: Text('Từ ${fmtDate(_from.toIso8601String())}'), onPressed: () => _pickDate(true)),
            ActionChip(avatar: const Icon(Icons.event_rounded, size: 16), label: Text('Đến ${fmtDate(_to.toIso8601String())}'), onPressed: () => _pickDate(false)),
            if (_usesGroupBy)
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'day', label: Text('Ngày')), ButtonSegment(value: 'month', label: Text('Tháng'))],
                selected: {_groupBy},
                onSelectionChanged: (s) => setState(() => _groupBy = s.first),
              ),
          ]),
          if (_usesBatchFilters)
            Wrap(spacing: 8, runSpacing: 4, children: [
              ActionChip(avatar: const Icon(Icons.factory_rounded, size: 16), label: Text(_facility == null ? 'Cơ sở: tất cả' : _facility!.s('label')), onPressed: () => _pickRef(true)),
              ActionChip(avatar: const Icon(Icons.spa_rounded, size: 16), label: Text(_species == null ? 'Giống: tất cả' : _species!.s('label')), onPressed: () => _pickRef(false)),
              PopupMenuButton<String>(
                // PopupMenu không gọi onSelected với null nên dùng 'ALL' làm giá trị "bỏ lọc".
                onSelected: (v) => setState(() {
                  _status = v == 'ALL' ? null : v;
                  _page = 1;
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'ALL', child: Text('Mọi trạng thái lô')),
                  for (final e in batchStatusLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                ],
                child: Chip(avatar: const Icon(Icons.flag_outlined, size: 16), label: Text(_status == null ? 'Trạng thái lô: tất cả' : label(batchStatusLabels, _status))),
              ),
            ]),
          const SizedBox(height: 12),
          if (rangeErr != null)
            Text(rangeErr, style: TextStyle(color: theme.colorScheme.error))
          else
            SizedBox(
              // chiều cao co giãn theo nội dung nhờ FutureBody + shrinkWrap bên trong
              child: FutureBody<J>(
                key: ValueKey(_sig),
                load: () => FarmApi.instance.get('/reports/$_group', query: _query()),
                builder: (ctx, r, _) => _content(ctx, r),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pager(J r) {
    final p = r.m('pagination') ?? {};
    final total = p.i('totalPages') ?? 0;
    final cur = p.i('currentPage') ?? _page;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: cur <= 1 ? null : () => setState(() => _page = cur - 1), icon: const Icon(Icons.chevron_left_rounded)),
      Text('Trang $cur/${total < 1 ? 1 : total} · ${p.i('totalItems') ?? 0} dòng', style: Theme.of(context).textTheme.bodySmall),
      IconButton(onPressed: cur >= total ? null : () => setState(() => _page = cur + 1), icon: const Icon(Icons.chevron_right_rounded)),
    ]);
  }

  Widget _kpi(String t, String v, {Color? color}) => SizedBox(
        width: 150,
        child: SoftCard(
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(v, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
          ]),
        ),
      );

  /// Thanh số liệu: luôn kèm con số, nên vẫn đọc được khi cỡ chữ lớn.
  Widget _bars(String title, List<MapEntry<String, double>> rows, String Function(double) fmt) {
    final theme = Theme.of(context);
    final maxV = rows.fold<double>(0, (a, e) => e.value.abs() > a ? e.value.abs() : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      if (rows.isEmpty) Text('Chưa có dữ liệu', style: theme.textTheme.bodySmall),
      for (final e in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 78, child: Text(e.key, style: theme.textTheme.bodySmall)), // period do server trả, không tự gom lại
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: maxV == 0 ? 0 : e.value.abs() / maxV, minHeight: 8),
              ),
            ),
            const SizedBox(width: 8),
            Text(fmt(e.value), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }

  Widget _content(BuildContext context, J r) {
    final theme = Theme.of(context);
    switch (_group) {
      case 'overview': {
        final d = r.m('data') ?? {};
        final c = d.m('cultivation') ?? {};
        final cl = d.m('classifier') ?? {};
        final au = d.m('audit') ?? {};
        final sb = c.m('statusBreakdown') ?? {}; // object theo enum, không phải array
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('Số lô', '${c.i('batchCount') ?? 0}'),
            _kpi('Sản lượng', kg(c.d('totalHarvestKg'))),
            _kpi('Lượt nhận diện', '${cl.i('total') ?? 0}'),
            _kpi('Hành động hệ thống', '${au.i('totalActions') ?? 0}'),
          ]),
          const SizedBox(height: 8),
          Text('Bộ lọc cơ sở/giống/trạng thái chỉ áp dụng cho phần nuôi trồng; nhận diện và hoạt động chỉ theo ngày.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Chip(label: Text('Cơ sở ${c.i('facilities') ?? 0}')),
            Chip(label: Text('Giống ${c.i('species') ?? 0}')),
            Chip(label: Text('Lô trễ hạn ${c.i('overdueBatches') ?? 0}')),
            Chip(label: Text('Nhận diện thành công ${cl.i('succeeded') ?? 0}')),
            Chip(label: Text('Nhận diện thất bại ${cl.i('failed') ?? 0}')),
            Chip(label: Text('Độ tin cậy TB ${pct01(cl.d('averageConfidence'))}')),
            Chip(label: Text('Hành động lỗi ${au.i('failedActions') ?? 0}')),
          ]),
          const SizedBox(height: 14),
          Text('Lô theo trạng thái', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in sb.entries)
              Chip(label: Text('${label(batchStatusLabels, e.key)}: ${(e.value as Map)['count'] ?? 0}')),
          ]),
          const SizedBox(height: 16),
          _bars('Sản lượng thu hoạch', [for (final s in c.l('harvestSeries')) MapEntry(s.s('period'), s.d('totalYieldKg') ?? 0)], (v) => kg(v)),
          const SizedBox(height: 14),
          _bars('Lượt nhận diện', [for (final s in cl.l('series')) MapEntry(s.s('period'), (s.i('count') ?? 0).toDouble())], (v) => v.toInt().toString()),
          const SizedBox(height: 14),
          _bars('Hành động hệ thống', [for (final s in au.l('series')) MapEntry(s.s('period'), (s.i('count') ?? 0).toDouble())], (v) => v.toInt().toString()),
        ]);

      }
      case 'financial': {
        final s = r.m('summary') ?? {};
        final profit = s.sn('profit');
        final loss = profit != null && profit.startsWith('-');
        final margin = s.sn('profitMarginPercent');
        final rows = r.l('data');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Số liệu THEO KỲ, khác tổng toàn vòng đời ở tab Tài chính của lô.
          Text('Số liệu theo kỳ đã chọn', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _kpi('Doanh thu', vnd(s.sn('revenue'))),
            _kpi('Tổng chi', vnd(s.sn('totalCost'))),
            _kpi(loss ? 'Lỗ' : 'Lời', vnd(profit), color: loss ? AppColors.danger : AppColors.success),
            _kpi('Tỷ suất', margin == null ? 'Chưa có dữ liệu' : '$margin%'),
            _kpi('Thu hoạch', kg(s.d('totalHarvestKg'))),
            _kpi('Đã bán', kg(s.d('totalSoldKg'))),
          ]),
          const SizedBox(height: 14),
          Text('Doanh thu – chi phí – lợi nhuận theo kỳ', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          if (r.l('series').isEmpty) Text('Chưa có dữ liệu', style: theme.textTheme.bodySmall),
          for (final x in r.l('series'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('${x.s('period')}: thu ${vnd(x.sn('revenue'))} · chi ${vnd(x.sn('totalCost'))} · ${vnd(x.sn('profit'))}',
                  style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 14),
          Text('Theo lô', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          if (rows.isEmpty) const EmptyView('Không có lô nào khớp bộ lọc.'),
          for (final b in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                onTap: b.i('batchId') == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batchId: b.i('batchId')!))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(b.s('batchCode'), style: theme.textTheme.titleSmall)),
                    StatusChip(text: label(batchStatusLabels, b.sn('status')), color: statusColor(b.sn('status'))),
                  ]),
                  Text('${b.m('facility')?.s('name') ?? b.s('facility')} · ${b.m('mushroom')?.s('commonName') ?? b.s('mushroom')}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Thu ${vnd(b.sn('revenue'))} · Chi ${vnd(b.sn('totalCost'))} · ${vnd(b.sn('profit'))}'),
                ]),
              ),
            ),
          _pager(r),
        ]);

      }
      case 'cultivation': {
        final rows = r.l('data');
        return Column(children: [
          if (rows.isEmpty) const EmptyView('Không có lô nào bắt đầu trong kỳ.'),
          for (final b in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              // Dòng báo cáo nuôi trồng không có batchId nên không mở chi tiết (không lấy batchCode làm ID).
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(b.s('batchCode'), style: theme.textTheme.titleSmall)),
                    StatusChip(text: label(batchStatusLabels, b.sn('status')), color: statusColor(b.sn('status'))),
                  ]),
                  Text('${b.s('facility')} (${b.s('province')}) · ${b.s('mushroom')}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Bắt đầu ${fmtDate(b.sn('startDate'))} · Thu hoạch ${kg(b.d('totalHarvestKg'))} · Lỗi ${b.d('defectRate') ?? '—'}%'),
                  if (b.sn('latestGrowthStage') != null)
                    Text('Sinh trưởng mới nhất: ${b.s('latestGrowthStage')} (${fmtDate(b.sn('latestGrowthRecordedAt'))})', style: theme.textTheme.bodySmall),
                ]),
              ),
            ),
          _pager(r),
        ]);

      }
      case 'classifier': {
        final rows = r.l('data');
        return Column(children: [
          if (rows.isEmpty) const EmptyView('Chưa có lượt nhận diện trong kỳ.'),
          for (final x in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(x.sn('predictedName') ?? 'Chưa có kết quả', style: theme.textTheme.titleSmall)),
                    StatusChip(text: label(classifierStatusLabels, x.sn('status')), color: statusColor(x.sn('status'))),
                  ]),
                  Text('${x.s('originalName')} · ${pct01(x.d('confidence'))} · ${label(classifierEdibilityLabels, x.sn('edibility'))}', style: theme.textTheme.bodySmall),
                  Text('${x.m('user')?.sn('username') ?? '—'} · ${fmtDateTime(x.sn('createdAt'))}', style: theme.textTheme.bodySmall),
                ]),
              ),
            ),
          _pager(r),
        ]);
      }
      default: {
        // audit
        final rows = r.l('data');
        return Column(children: [
          if (rows.isEmpty) const EmptyView('Chưa có hoạt động trong kỳ.'),
          for (final x in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(x.s('action'), style: theme.textTheme.titleSmall)),
                    StatusChip(text: '${x.s('outcome')} · ${x.s('statusCode')}', color: statusColor(x.sn('outcome'))),
                  ]),
                  Text('${x.sn('actorUsername') ?? 'Hệ thống'} · ${x.s('method')} ${x.s('path')}', style: theme.textTheme.bodySmall),
                  Text(fmtDateTime(x.sn('createdAt')), style: theme.textTheme.bodySmall),
                ]),
              ),
            ),
          _pager(r),
        ]);
      }
    }
  }
}
