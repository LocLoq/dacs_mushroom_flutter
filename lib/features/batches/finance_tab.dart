import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/soft_card.dart';

/// Tab Tài chính của lô (specs/S18_FINANCIALS.md). Chỉ manager/admin.
/// Tiền là chuỗi Decimal: hiển thị bằng vnd() và gửi nguyên chuỗi, KHÔNG qua double.
class FinanceTab extends StatefulWidget {
  final int batchId;
  final ValueNotifier<int> refresh; // tăng khi vừa ghi thu hoạch

  const FinanceTab({super.key, required this.batchId, required this.refresh});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  final _summaryKey = GlobalKey<FutureBodyState<J>>();
  final _expKey = GlobalKey<_EntryListState>();
  final _saleKey = GlobalKey<_EntryListState>();

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_reloadAll);
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_reloadAll);
    super.dispose();
  }

  void _reloadAll() {
    _summaryKey.currentState?.reload();
    _expKey.currentState?.load();
    _saleKey.currentState?.load();
  }

  Widget _kpi(String title, String value, {Color? color}) => SizedBox(
        width: 160,
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          radius: 16,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBody<J>(
          key: _summaryKey,
          load: () async =>
              (await FarmApi.instance.get('/cultivation-batches/${widget.batchId}/financial-summary')).m('data') ?? {},
          builder: (ctx, s, _) {
            final profit = s.sn('profit');
            final loss = profit != null && profit.startsWith('-');
            final margin = s.sn('profitMarginPercent');
            final perKg = s.sn('costPerHarvestKg');
            final costs = s.m('costsByCategory') ?? {};
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                _kpi('Sản lượng thu hoạch', kg(s.d('totalHarvestKg'))),
                _kpi('Đã bán', kg(s.d('totalSoldKg'))),
                _kpi('Doanh thu', vnd(s.sn('revenue'))),
                _kpi('Tổng chi', vnd(s.sn('totalCost'))),
                _kpi(loss ? 'Lỗ' : 'Lời', vnd(profit), color: loss ? AppColors.danger : AppColors.success),
                _kpi('Tỷ suất lợi nhuận', margin == null ? 'Chưa có dữ liệu' : '$margin%'),
                _kpi('Chi phí/kg thu hoạch', perKg == null ? 'Chưa có dữ liệu' : vnd(perKg)),
              ]),
              const SizedBox(height: 12),
              Text('Chi phí theo nhóm', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in costs.entries)
                  Chip(label: Text('${label(expenseCategoryLabels, e.key)}: ${vnd(e.value?.toString())}')),
              ]),
            ]);
          },
        ),
        const SizedBox(height: 20),
        _EntryList(
          key: _expKey,
          batchId: widget.batchId,
          kind: 'expenses',
          onMutated: () => _summaryKey.currentState?.reload(),
        ),
        const SizedBox(height: 20),
        _EntryList(
          key: _saleKey,
          batchId: widget.batchId,
          kind: 'sales',
          onMutated: () => _summaryKey.currentState?.reload(),
        ),
      ],
    );
  }
}

List<FieldDef> _expenseFields() => const [
      FieldDef('name', 'Tên khoản chi', FieldType.text, required: true, maxLen: 255),
      FieldDef('category', 'Nhóm', FieldType.choice, required: true, options: expenseCategoryLabels),
      FieldDef('quantity', 'Số lượng', FieldType.decimal, required: true, positive: true, maxDecimals: 3),
      FieldDef('unit', 'Đơn vị', FieldType.text, required: true, maxLen: 50),
      FieldDef('unitPrice', 'Đơn giá (VND)', FieldType.decimal, required: true, maxDecimals: 2),
      FieldDef('incurredAt', 'Thời điểm phát sinh', FieldType.dateTime),
      FieldDef('notes', 'Ghi chú', FieldType.multiline, nullable: true, maxLen: 10000),
    ];

List<FieldDef> _saleFields() => const [
      FieldDef('quantityKg', 'Số lượng (kg)', FieldType.decimal, required: true, positive: true, maxDecimals: 3),
      FieldDef('unitPrice', 'Đơn giá (VND/kg)', FieldType.decimal, required: true, maxDecimals: 2),
      FieldDef('soldAt', 'Thời điểm bán', FieldType.dateTime),
      FieldDef('buyer', 'Người mua', FieldType.text, nullable: true, maxLen: 255),
      FieldDef('notes', 'Ghi chú', FieldType.multiline, nullable: true, maxLen: 10000),
    ];

class _EntryList extends StatefulWidget {
  final int batchId;
  final String kind; // expenses | sales
  final VoidCallback onMutated;

  const _EntryList({super.key, required this.batchId, required this.kind, required this.onMutated});

  @override
  State<_EntryList> createState() => _EntryListState();
}

class _EntryListState extends State<_EntryList> {
  PageData _data = PageData.empty;
  int _page = 1;
  bool _loading = true;
  String? _error;

  bool get _isExp => widget.kind == 'expenses';
  String get _base => '/cultivation-batches/${widget.batchId}/${widget.kind}';
  String get _dateKey => _isExp ? 'incurredAt' : 'soldAt';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await FarmApi.instance.get(_base, query: {'page': _page, 'limit': 10});
      if (!mounted) return;
      setState(() {
        _data = PageData.from(r);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final ok = await showFormSheet(
      context,
      title: _isExp ? 'Thêm khoản chi' : 'Ghi lần bán',
      fields: _isExp ? _expenseFields() : _saleFields(),
      initial: {_dateKey: DateTime.now(), if (_isExp) 'category': 'MATERIAL'},
      onSubmit: (b) => FarmApi.instance.post(_base, b),
    );
    if (ok) _afterMutation();
  }

  /// PATCH chỉ gửi field thực sự thay đổi; không gửi amount/id/metadata.
  J _diff(J initial, J body) {
    final out = <String, dynamic>{};
    body.forEach((k, v) {
      final old = initial[k];
      if (k == _dateKey) {
        final a = parseIso(old?.toString())?.millisecondsSinceEpoch;
        final b = parseIso(v?.toString())?.millisecondsSinceEpoch;
        if (a == null || b == null || (a ~/ 60000) != (b ~/ 60000)) out[k] = v;
      } else if ((old?.toString() ?? '') != (v?.toString() ?? '')) {
        out[k] = v;
      }
    });
    return out;
  }

  Future<void> _edit(J e) async {
    final ok = await showFormSheet(
      context,
      title: _isExp ? 'Sửa khoản chi' : 'Sửa lần bán',
      fields: _isExp ? _expenseFields() : _saleFields(),
      initial: e,
      isEdit: true,
      onSubmit: (b) async {
        final changed = _diff(e, b);
        if (changed.isEmpty) return; // không có gì đổi -> không gọi API
        await FarmApi.instance.patch('$_base/${e.i('id')}', changed);
      },
    );
    if (ok) _afterMutation();
  }

  Future<void> _delete(J e) async {
    final yes = await confirmDialog(context,
        title: _isExp ? 'Xóa khoản chi?' : 'Xóa lần bán?',
        message: 'Số liệu tổng hợp sẽ được tính lại. Không hoàn tác.',
        ok: 'Xóa',
        danger: true);
    if (!yes) return;
    try {
      await FarmApi.instance.delete('$_base/${e.i('id')}');
      _afterMutation();
    } on ApiException catch (err) {
      if (mounted) toast(context, err.message, error: true);
    }
  }

  void _afterMutation() {
    load(); // reload list tương ứng + summary
    widget.onMutated();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(_isExp ? 'Khoản chi' : 'Lần bán', style: theme.textTheme.titleMedium)),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: _create,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_isExp ? 'Thêm chi' : 'Ghi bán'),
          ),
        ]),
        const SizedBox(height: 10),
        if (_loading && _data.items.isEmpty)
          const SizedBox(height: 100, child: LoadingView())
        else if (_error != null && _data.items.isEmpty)
          SizedBox(height: 140, child: ErrorView(message: _error!, onRetry: load))
        else if (_data.items.isEmpty)
          SizedBox(height: 100, child: EmptyView(_isExp ? 'Chưa có khoản chi.' : 'Chưa có lần bán.'))
        else
          for (final e in _data.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _isExp
                            ? '${e.s('name')} · ${label(expenseCategoryLabels, e.sn('category'))}'
                            : 'Bán ${e.s('quantityKg')} kg${e.sn('buyer') == null ? '' : ' · ${e.s('buyer')}'}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isExp
                            ? '${e.s('quantity')} ${e.s('unit')} × ${vnd(e.sn('unitPrice'))}'
                            : '${e.s('quantityKg')} kg × ${vnd(e.sn('unitPrice'))}',
                        style: theme.textTheme.bodySmall,
                      ),
                      // Thành tiền do SERVER tính, client không tự nhân.
                      Text('${vnd(e.sn('amount'))} · ${fmtDate(e.sn(_dateKey))}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? _edit(e) : _delete(e),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      PopupMenuItem(value: 'del', child: Text('Xóa')),
                    ],
                  ),
                ]),
              ),
            ),
        if (_data.totalPages > 1)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: (_loading || _page <= 1) ? null : () { _page--; load(); }, icon: const Icon(Icons.chevron_left_rounded)),
            Text('Trang $_page/${_data.totalPages}', style: theme.textTheme.bodySmall),
            IconButton(onPressed: (_loading || _page >= _data.totalPages) ? null : () { _page++; load(); }, icon: const Icon(Icons.chevron_right_rounded)),
          ]),
      ],
    );
  }
}
