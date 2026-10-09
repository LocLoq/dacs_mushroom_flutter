import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../network/farm_api.dart';
import '../utils/format.dart';
import '../utils/json_utils.dart';
import 'paged_list.dart';

enum FieldType {
  text,
  multiline,
  integer,
  number,
  decimal,
  date,
  dateTime,
  choice,
  password,
  pickOne,
  pickMany,
  check,
}

/// Nguồn dữ liệu cho ô chọn tham chiếu (có search + phân trang, giữ lựa chọn qua trang).
class PickerSource {
  final String title;
  final Future<PageData> Function(int page, String search) fetch;
  final String Function(J item) label;
  final String Function(J item)? subtitle;

  const PickerSource({
    required this.title,
    required this.fetch,
    required this.label,
    this.subtitle,
  });
}

class FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final bool required;

  /// Gửi null khi SỬA nếu để trống (xoá giá trị); khi TẠO thì bỏ khỏi body.
  final bool nullable;
  final bool readOnly;
  final Map<String, String>? options; // choice
  final PickerSource? picker;
  final int? maxLen;
  final num? min;
  final num? max;
  final int? maxDecimals; // decimal
  final bool positive; // decimal/number phải > 0
  final String? helper;

  const FieldDef(
    this.key,
    this.label,
    this.type, {
    this.required = false,
    this.nullable = false,
    this.readOnly = false,
    this.options,
    this.picker,
    this.maxLen,
    this.min,
    this.max,
    this.maxDecimals,
    this.positive = false,
    this.helper,
  });
}

/// Mở form thích ứng (bottom sheet cuộn, footer Hủy/Lưu luôn thấy).
/// [initial]: giá trị ban đầu theo key (khi sửa). [initialPicks]: nhãn cho pickOne/pickMany.
/// [onSubmit] nhận body đã chuẩn hoá; ném ApiException để giữ form và hiện lỗi.
/// Trả true nếu đã lưu thành công.
Future<bool> showFormSheet(
  BuildContext context, {
  required String title,
  required List<FieldDef> fields,
  required Future<void> Function(J body) onSubmit,
  J initial = const {},
  Map<String, List<J>> initialPicks = const {},
  bool isEdit = false,
  String submitLabel = 'Lưu',
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (ctx) => _FormBody(
      title: title,
      fields: fields,
      onSubmit: onSubmit,
      initial: initial,
      initialPicks: initialPicks,
      isEdit: isEdit,
      submitLabel: submitLabel,
    ),
  );
  return r == true;
}

class _FormBody extends StatefulWidget {
  final String title;
  final List<FieldDef> fields;
  final Future<void> Function(J body) onSubmit;
  final J initial;
  final Map<String, List<J>> initialPicks;
  final bool isEdit;
  final String submitLabel;

  const _FormBody({
    required this.title,
    required this.fields,
    required this.onSubmit,
    required this.initial,
    required this.initialPicks,
    required this.isEdit,
    required this.submitLabel,
  });

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, dynamic> _val = {};
  final Map<String, String> _err = {};
  // pickOne: 1 phần tử; pickMany: nhiều. Mỗi phần tử {id, label}.
  final Map<String, List<J>> _picks = {};
  bool _busy = false;
  String? _topError;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final v = widget.initial[f.key];
      switch (f.type) {
        case FieldType.text:
        case FieldType.multiline:
        case FieldType.integer:
        case FieldType.number:
        case FieldType.decimal:
        case FieldType.password:
          _ctrl[f.key] = TextEditingController(text: v == null ? '' : v.toString());
          break;
        case FieldType.date:
        case FieldType.dateTime:
          _val[f.key] = v is DateTime ? v : parseIso(v?.toString());
          break;
        case FieldType.choice:
          _val[f.key] = v?.toString();
          break;
        case FieldType.check:
          _val[f.key] = v == true;
          break;
        case FieldType.pickOne:
        case FieldType.pickMany:
          _picks[f.key] = List<J>.from(widget.initialPicks[f.key] ?? const []);
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ───────── kiểm tra & dựng body ─────────

  bool _validateAndBuild(J out) {
    _err.clear();
    for (final f in widget.fields) {
      if (f.readOnly) continue;
      final t = _ctrl[f.key];
      final raw = t?.text ?? '';
      final text = f.type == FieldType.password ? raw : raw.trim();
      dynamic value;
      var empty = false;

      switch (f.type) {
        case FieldType.text:
        case FieldType.multiline:
        case FieldType.password:
          empty = text.isEmpty;
          value = text;
          if (!empty && f.maxLen != null && text.length > f.maxLen!) {
            _err[f.key] = 'Tối đa ${f.maxLen} ký tự';
          }
          break;
        case FieldType.integer:
          empty = text.isEmpty;
          if (!empty) {
            final n = int.tryParse(text);
            if (n == null) {
              _err[f.key] = 'Phải là số nguyên';
            } else if (f.min != null && n < f.min!) {
              _err[f.key] = 'Không nhỏ hơn ${f.min}';
            } else {
              value = n;
            }
          }
          break;
        case FieldType.number:
          empty = text.isEmpty;
          if (!empty) {
            final n = double.tryParse(text.replaceAll(',', '.'));
            if (n == null) {
              _err[f.key] = 'Phải là số';
            } else if (f.min != null && n < f.min!) {
              _err[f.key] = 'Không nhỏ hơn ${f.min}';
            } else if (f.max != null && n > f.max!) {
              _err[f.key] = 'Không lớn hơn ${f.max}';
            } else if (f.positive && n <= 0) {
              _err[f.key] = 'Phải lớn hơn 0';
            } else {
              value = n;
            }
          }
          break;
        case FieldType.decimal:
          // Giữ NGUYÊN dạng chuỗi, không qua double (tiền lớn sẽ mất chữ số).
          empty = text.isEmpty;
          if (!empty) {
            final s = text.replaceAll(',', '.');
            final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(s);
            if (m == null) {
              _err[f.key] = 'Số không hợp lệ (không âm, không dấu phân nhóm)';
            } else if ((m.group(2)?.length ?? 0) > (f.maxDecimals ?? 2)) {
              _err[f.key] = 'Tối đa ${f.maxDecimals ?? 2} chữ số thập phân';
            } else if (f.positive && RegExp(r'^0+(\.0*)?$').hasMatch(s)) {
              _err[f.key] = 'Phải lớn hơn 0';
            } else {
              value = s;
            }
          }
          break;
        case FieldType.date:
        case FieldType.dateTime:
          final dt = _val[f.key] as DateTime?;
          empty = dt == null;
          value = dt?.toUtc().toIso8601String();
          break;
        case FieldType.choice:
          empty = (_val[f.key] ?? '').toString().isEmpty;
          value = _val[f.key];
          break;
        case FieldType.check:
          value = _val[f.key] == true;
          break;
        case FieldType.pickOne:
          final one = _picks[f.key] ?? [];
          empty = one.isEmpty;
          value = empty ? null : one.first['id'];
          break;
        case FieldType.pickMany:
          final many = _picks[f.key] ?? [];
          // Chỉ gửi mảng ID số nguyên, không gửi object.
          value = many.map((e) => e['id']).toList();
          empty = false; // [] hợp lệ: bỏ toàn bộ liên kết
          break;
      }

      if (empty && f.required) {
        _err[f.key] = 'Bắt buộc';
        continue;
      }
      if (_err.containsKey(f.key)) continue;
      if (f.type == FieldType.check) {
        out[f.key] = value;
      } else if (f.type == FieldType.pickMany) {
        // Tạo mới mà không chọn gì thì bỏ khỏi body; sửa thì gửi [] để bỏ liên kết.
        if (widget.isEdit || (value as List).isNotEmpty) out[f.key] = value;
      } else if (empty) {
        if (widget.isEdit && f.nullable) out[f.key] = null;
        // tạo mới: bỏ field tuỳ chọn trống
      } else {
        out[f.key] = value;
      }
    }
    return _err.isEmpty;
  }

  Future<void> _submit() async {
    if (_busy) return; // chống nhấn đôi
    final body = <String, dynamic>{};
    if (!_validateAndBuild(body)) {
      setState(() => _topError = 'Vui lòng kiểm tra các ô được đánh dấu.');
      return;
    }
    setState(() {
      _busy = true;
      _topError = null;
    });
    try {
      await widget.onSubmit(body);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _topError = e.message); // giữ nguyên dữ liệu nhập
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── giao diện từng loại ô ─────────

  Future<void> _pickDate(FieldDef f) async {
    final now = DateTime.now();
    final cur = (_val[f.key] as DateTime?) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    var out = DateTime(d.year, d.month, d.day, cur.hour, cur.minute);
    if (f.type == FieldType.dateTime) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur));
      if (t != null) out = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    } else {
      out = DateTime(d.year, d.month, d.day, 12);
    }
    setState(() => _val[f.key] = out);
  }

  Future<void> _openPicker(FieldDef f) async {
    final many = f.type == FieldType.pickMany;
    final res = await showModalBottomSheet<List<J>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (ctx) => _PickerSheet(source: f.picker!, many: many, selected: _picks[f.key] ?? []),
    );
    if (res != null) setState(() => _picks[f.key] = res);
  }

  Widget _field(FieldDef f) {
    final theme = Theme.of(context);
    final err = _err[f.key];
    final label = f.required ? '${f.label} *' : f.label;

    switch (f.type) {
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.integer:
      case FieldType.number:
      case FieldType.decimal:
      case FieldType.password:
        return TextField(
          controller: _ctrl[f.key],
          enabled: !f.readOnly && !_busy,
          obscureText: f.type == FieldType.password,
          minLines: f.type == FieldType.multiline ? 3 : 1,
          maxLines: f.type == FieldType.multiline ? 6 : 1,
          keyboardType: switch (f.type) {
            FieldType.integer => TextInputType.number,
            FieldType.number || FieldType.decimal => const TextInputType.numberWithOptions(decimal: true),
            FieldType.multiline => TextInputType.multiline,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(labelText: label, helperText: f.helper, errorText: err),
        );
      case FieldType.date:
      case FieldType.dateTime:
        final d = _val[f.key] as DateTime?;
        final shown = d == null
            ? ''
            : (f.type == FieldType.date
                ? fmtDate(d.toIso8601String())
                : fmtDateTime(d.toIso8601String()));
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (f.readOnly || _busy) ? null : () => _pickDate(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: err,
              suffixIcon: d != null && !f.required && !f.readOnly
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _val[f.key] = null),
                    )
                  : const Icon(Icons.event_rounded),
            ),
            child: Text(shown.isEmpty ? 'Chọn ngày' : shown,
                style: TextStyle(color: shown.isEmpty ? theme.colorScheme.onSurfaceVariant : null)),
          ),
        );
      case FieldType.choice:
        return DropdownButtonFormField<String>(
          initialValue: _val[f.key] as String?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, errorText: err),
          items: [
            for (final e in f.options!.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (f.readOnly || _busy) ? null : (v) => setState(() => _val[f.key] = v),
        );
      case FieldType.check:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _val[f.key] == true,
          onChanged: _busy ? null : (v) => setState(() => _val[f.key] = v == true),
          title: Text(f.label),
          subtitle: f.helper == null ? null : Text(f.helper!),
          controlAffinity: ListTileControlAffinity.leading,
        );
      case FieldType.pickOne:
      case FieldType.pickMany:
        final picks = _picks[f.key] ?? [];
        final many = f.type == FieldType.pickMany;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (f.readOnly || _busy) ? null : () => _openPicker(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: err,
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            ),
            child: picks.isEmpty
                ? Text(many ? 'Chọn (có thể chọn nhiều)' : 'Chọn',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                : many
                    ? Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [for (final p in picks) Chip(label: Text(p.s('label')))],
                      )
                    : Text(picks.first.s('label')),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: theme.textTheme.titleLarge)),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_topError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_topError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                  for (final f in widget.fields) ...[
                    _field(f),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(widget.submitLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chọn tham chiếu có search + phân trang; giữ lựa chọn qua trang; bấm Xác nhận mới áp dụng.
class _PickerSheet extends StatefulWidget {
  final PickerSource source;
  final bool many;
  final List<J> selected;

  const _PickerSheet({required this.source, required this.many, required this.selected});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late final Map<Object, J> _sel = {
    for (final s in widget.selected) s['id'] as Object: s,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(widget.source.title, style: theme.textTheme.titleLarge)),
                if (!widget.many)
                  TextButton(onPressed: () => Navigator.pop(context, <J>[]), child: const Text('Bỏ chọn')),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Expanded(
            child: PagedListView(
              searchHint: 'Tìm kiếm',
              fetch: widget.source.fetch,
              itemBuilder: (ctx, item, _) {
                final id = item['id'] as Object;
                final on = _sel.containsKey(id);
                return Material(
                  color: on ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(widget.source.label(item)),
                    subtitle: widget.source.subtitle == null ? null : Text(widget.source.subtitle!(item)),
                    trailing: Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: on ? theme.colorScheme.primary : null),
                    onTap: () => setState(() {
                      if (widget.many) {
                        on ? _sel.remove(id) : _sel[id] = {'id': id, 'label': widget.source.label(item)};
                      } else {
                        _sel
                          ..clear()
                          ..[id] = {'id': id, 'label': widget.source.label(item)};
                      }
                    }),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _sel.values.toList()),
              child: Text(widget.many ? 'Xác nhận (${_sel.length} đã chọn)' : 'Xác nhận'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mở picker một lựa chọn độc lập (ngoài form).
/// Trả: null = đóng sheet (giữ nguyên giá trị cũ); [] = "Bỏ chọn"; [ {id,label} ] = đã chọn.
Future<List<J>?> pickOneFrom(BuildContext context, PickerSource source) {
  return showModalBottomSheet<List<J>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (ctx) => _PickerSheet(source: source, many: false, selected: const []),
  );
}
