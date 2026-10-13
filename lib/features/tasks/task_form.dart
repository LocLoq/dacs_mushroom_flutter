import 'package:flutter/material.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/form_sheet.dart';
import 'task_list_screen.dart';

Future<bool> showTaskForm(
  BuildContext context, {
  J? task,
  required Future<void> Function(J) onSubmit,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => _TaskForm(task: task, onSubmit: onSubmit),
    ) ==
    true;

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.task, required this.onSubmit});
  final J? task;
  final Future<void> Function(J) onSubmit;
  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.task?.s('title') ?? '',
  );
  late final _description = TextEditingController(
    text: widget.task?.s('description') ?? '',
  );
  late int? _batchId = widget.task?.i('batchId');
  late String _batchLabel = widget.task?.s('batchCode') ?? '';
  late int? _assigneeId = widget.task?.i('assigneeUserId');
  late String _assigneeLabel = widget.task?.m('assignee')?.s('full_name') ?? '';
  late DateTime? _due = parseIso(widget.task?.sn('dueAt'));
  bool _busy = false;
  String? _error;
  bool get _locked => widget.task?.sn('status') == 'PENDING_REVIEW';
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickBatch() async {
    final picked = await pickOneFrom(context, batchPicker());
    if (picked == null || !mounted) return;
    final id = picked.isEmpty ? null : picked.first['id'] as int?;
    setState(() {
      if (id != _batchId) {
        _assigneeId = null;
        _assigneeLabel = '';
      }
      _batchId = id;
      _batchLabel = picked.isEmpty ? '' : picked.first.s('label');
    });
  }

  Future<void> _pickAssignee() async {
    final picked = await pickOneFrom(
      context,
      assigneePicker(batchId: _batchId),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _assigneeId = picked.isEmpty ? null : picked.first['id'] as int?;
      _assigneeLabel = picked.isEmpty ? '' : picked.first.s('label');
    });
  }

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? DateTime.now()),
    );
    if (mounted && time != null)
      setState(
        () => _due = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'title': _title.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        if (!_locked) 'batchId': _batchId,
        if (!_locked) 'assigneeUserId': _assigneeId,
        'dueAt': _due?.toUtc().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.task == null ? 'Giao việc mới' : 'Sửa công việc',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextFormField(
              controller: _title,
              enabled: !_busy,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Nhập tiêu đề' : null,
            ),
            TextFormField(
              controller: _description,
              enabled: !_busy,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            ListTile(
              title: Text(
                _batchLabel.isEmpty
                    ? 'Chọn lô (không bắt buộc)'
                    : 'Lô: $_batchLabel',
              ),
              trailing: const Icon(Icons.expand_more),
              onTap: _locked || _busy ? null : _pickBatch,
            ),
            ListTile(
              title: Text(
                _assigneeLabel.isEmpty
                    ? 'Chọn người nhận (không bắt buộc)'
                    : 'Người nhận: $_assigneeLabel',
              ),
              trailing: const Icon(Icons.person_outline),
              onTap: _locked || _busy ? null : _pickAssignee,
            ),
            if (_locked)
              const Text('Công việc chờ duyệt: giữ nguyên lô và người nhận.'),
            ListTile(
              title: Text(
                _due == null
                    ? 'Chọn hạn hoàn thành'
                    : fmtDateTime(_due!.toIso8601String()),
              ),
              onTap: _busy ? null : _pickDue,
              trailing: IconButton(
                onPressed: _busy ? null : () => setState(() => _due = null),
                icon: const Icon(Icons.clear),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
            ),
          ],
        ),
      ),
    ),
  );
}
