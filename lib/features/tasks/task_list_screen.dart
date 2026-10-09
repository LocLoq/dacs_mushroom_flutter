import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import 'task_detail_screen.dart';

/// Danh sách và giao việc (specs/S17_TASK_EVIDENCE.md §1).
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

PickerSource batchPicker() => PickerSource(
      title: 'Chọn lô',
      fetch: (p, s) async => PageData.from(
          await FarmApi.instance.get('/cultivation-batches', query: {'page': p, 'limit': 10, 'search': s})),
      label: (i) => i.s('batchCode'),
      subtitle: (i) => i.m('mushroom')?.s('commonName') ?? '',
    );

/// Người nhận lấy từ task-assignees (KHÔNG dùng admin/users).
PickerSource assigneePicker() => PickerSource(
      title: 'Chọn người nhận',
      fetch: (p, s) async => PageData.from(
          await FarmApi.instance.get('/dashboard/task-assignees', query: {'page': p, 'limit': 10, 'search': s})),
      label: (i) => i.s('full_name').isEmpty ? i.s('username') : i.s('full_name'),
      subtitle: (i) => '${i.s('username')} · ${label(roleLabels, i.sn('role'))}',
    );

List<FieldDef> taskFields({bool lockLinks = false}) => [
      const FieldDef('title', 'Tiêu đề', FieldType.text, required: true, maxLen: 255),
      const FieldDef('description', 'Mô tả', FieldType.multiline, nullable: true),
      // PENDING_REVIEW: khoá và BỎ khỏi request cả batchId lẫn assigneeUserId.
      if (!lockLinks) FieldDef('batchId', 'Lô nuôi', FieldType.pickOne, nullable: true, picker: batchPicker()),
      if (!lockLinks) FieldDef('assigneeUserId', 'Người nhận', FieldType.pickOne, nullable: true, picker: assigneePicker()),
      const FieldDef('dueAt', 'Hạn hoàn thành', FieldType.dateTime, nullable: true),
    ];

class _TaskListScreenState extends State<TaskListScreen> {
  final _key = GlobalKey<PagedListViewState>();
  String _status = 'DEFAULT'; // DEFAULT = không gửi status -> TODO+IN_PROGRESS+PENDING_REVIEW
  bool _mine = false;
  J? _batch; // lọc theo lô {id,label}

  Future<void> _create() async {
    final ok = await showFormSheet(
      context,
      title: 'Giao việc mới',
      fields: taskFields(), // tạo mới không có lựa chọn COMPLETED
      onSubmit: (b) => FarmApi.instance.post('/dashboard/tasks', b),
    );
    if (ok) _key.currentState?.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = <String, String>{
      'DEFAULT': 'Đang mở',
      'ALL': 'Tất cả',
      ...taskStatusLabels,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Công việc')),
      floatingActionButton: LocalSession.canManage
          ? FloatingActionButton.extended(
              onPressed: _create, icon: const Icon(Icons.add_task_rounded), label: const Text('Giao việc'))
          : null,
      body: PagedListView(
        key: _key,
        searchHint: 'Tìm theo tiêu đề',
        emptyText: 'Không có công việc nào.',
        deps: [_status, _mine, _batch?['id']],
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.eco_rounded, size: 16),
                  label: Text(_batch == null ? 'Lô: tất cả' : 'Lô ${_batch!.s('label')}'),
                  onPressed: () async {
                    final r = await pickOneFrom(context, batchPicker());
                    if (r == null) return; // đóng sheet: giữ bộ lọc cũ
                    setState(() => _batch = r.isEmpty ? null : r.first); // "Bỏ chọn" -> bỏ lọc
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Việc của tôi'),
                  selected: _mine,
                  onSelected: (v) => setState(() => _mine = v),
                ),
              ),
              for (final e in filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) => setState(() => _status = e.key),
                  ),
                ),
            ]),
          ),
        ),
        fetch: (p, s) async => PageData.from(await FarmApi.instance.get('/dashboard/tasks', query: {
          'page': p,
          'limit': 10,
          'search': s,
          'status': _status == 'DEFAULT' ? null : _status,
          'assigneeUserId': _mine ? LocalSession.userId : null,
          'batchId': _batch?['id'],
        })),
        itemBuilder: (ctx, t, reload) {
          final st = t.sn('status');
          final a = t.m('assignee');
          return SoftCard(
            padding: const EdgeInsets.all(14),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.s('id'))));
              reload();
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.s('title'), style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                StatusChip(text: label(taskStatusLabels, st), color: statusColor(st)),
              ]),
              const SizedBox(height: 6),
              Text(
                [
                  if (t.sn('batchCode') != null) 'Lô ${t.s('batchCode')}',
                  'Nhận: ${a == null ? 'Chưa giao' : (a.s('full_name').isEmpty ? a.s('username') : a.s('full_name'))}',
                  'Hạn: ${fmtDate(t.sn('dueAt'))}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ]),
          );
        },
      ),
    );
  }
}
