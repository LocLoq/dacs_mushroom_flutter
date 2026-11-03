import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../batches/batch_detail_screen.dart';
import 'evidence_sheet.dart';
import 'task_list_screen.dart';

/// Chi tiết công việc, minh chứng và duyệt (specs/S17_TASK_EVIDENCE.md §2–§5).
class TaskDetailScreen extends StatefulWidget {
  final String taskId; // UUID, không parse int

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _api = FarmApi.instance;
  final _key = GlobalKey<FutureBodyState<J>>();

  String get _path => '/dashboard/tasks/${widget.taskId}';

  Future<J> _load() async => (await _api.get(_path)).m('data') ?? {};

  void _reload() => _key.currentState?.reload();

  /// Chạy một thao tác; 409 -> tải lại task, báo trạng thái đã đổi, KHÔNG tự gửi lại.
  Future<void> _mutate(Future<void> Function() f, {String? okMsg}) async {
    try {
      await f();
      if (okMsg != null && mounted) toast(context, okMsg);
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        toast(context, 'Trạng thái công việc đã thay đổi. Đã tải lại dữ liệu mới.', error: true);
        _reload();
      } else {
        toast(context, e.message, error: true);
      }
    }
  }

  Future<void> _setStatus(String status, {String? okMsg}) =>
      _mutate(() => _api.patch(_path, {'status': status}), okMsg: okMsg);

  Future<void> _edit(J t) async {
    final locked = t.sn('status') == 'PENDING_REVIEW';
    final ok = await showFormSheet(
      context,
      title: 'Sửa công việc',
      fields: taskFields(lockLinks: locked),
      initial: t,
      initialPicks: {
        if (t.i('batchId') != null) 'batchId': [{'id': t.i('batchId'), 'label': t.s('batchCode')}],
        if (t.m('assignee') != null)
          'assigneeUserId': [
            {
              'id': t.m('assignee')!.i('id'),
              'label': t.m('assignee')!.s('full_name').isEmpty ? t.m('assignee')!.s('username') : t.m('assignee')!.s('full_name'),
            }
          ],
      },
      isEdit: true,
      onSubmit: (b) => _api.patch(_path, b),
    );
    if (ok) _reload();
  }

  Future<void> _cancel() async {
    final yes = await confirmDialog(context,
        title: 'Hủy công việc?',
        message: 'Lịch sử gửi minh chứng được giữ lại. Lần gửi đang chờ duyệt sẽ chuyển sang Đã hủy.',
        ok: 'Hủy việc',
        danger: true);
    if (yes) await _setStatus('CANCELLED', okMsg: 'Đã hủy công việc');
  }

  Future<void> _reopen() async {
    final yes = await confirmDialog(context,
        title: 'Mở lại công việc?', message: 'Công việc quay về Đang thực hiện, lịch sử được giữ nguyên.', ok: 'Mở lại');
    if (yes) await _setStatus('IN_PROGRESS', okMsg: 'Đã mở lại công việc');
  }

  Future<void> _delete(J t) async {
    final yes = await confirmDialog(context,
        title: 'Xóa công việc?', message: '"${t.s('title')}" sẽ bị xóa. Không hoàn tác.', ok: 'Xóa', danger: true);
    if (!yes) return;
    try {
      await _api.delete(_path);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.isConflict ? 'Công việc đã có lịch sử, hãy dùng Hủy việc.' : e.message, error: true);
      if (e.isConflict) _reload();
    }
  }

  Future<void> _submitEvidence(J t) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => EvidenceSheet(task: t),
    );
    if (ok == true) _reload(); // reload task, khoá gửi tiếp vì đã PENDING_REVIEW
  }

  Future<void> _review(J sub, bool approve) async {
    final subPath = '$_path/submissions/${sub.s('id')}/review';
    if (approve) {
      final yes = await confirmDialog(context,
          title: 'Duyệt minh chứng?', message: 'Công việc sẽ chuyển sang Hoàn thành.', ok: 'Duyệt');
      if (!yes) return;
      await _mutate(() => _api.post(subPath, {'decision': 'APPROVE'}), okMsg: 'Đã duyệt');
      return;
    }
    final c = TextEditingController();
    String? err;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Trả lại minh chứng'),
          content: TextField(
            controller: c,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(labelText: 'Lý do (bắt buộc)', errorText: err),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final r = c.text.trim();
                if (r.isEmpty) return setS(() => err = 'Bắt buộc nhập lý do');
                if (r.length > 10000) return setS(() => err = 'Tối đa 10.000 ký tự');
                Navigator.pop(ctx, r);
              },
              child: const Text('Trả lại'),
            ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await _mutate(() => _api.post(subPath, {'decision': 'REJECT', 'reason': reason}), okMsg: 'Đã trả lại');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết công việc'), actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: FutureBody<J>(key: _key, load: _load, builder: (ctx, t, _) => _body(ctx, t)),
    );
  }

  Widget _body(BuildContext context, J t) {
    final theme = Theme.of(context);
    final st = t.sn('status');
    final me = LocalSession.userId;
    final canManage = LocalSession.canManage;
    final isAssignee = t.i('assigneeUserId') != null && t.i('assigneeUserId') == me;
    final open = st == 'TODO' || st == 'IN_PROGRESS';
    final subs = t.l('submissions')
      ..sort((a, b) => (b.sn('submittedAt') ?? '').compareTo(a.sn('submittedAt') ?? ''));
    final a = t.m('assignee');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(t.s('title'), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        StatusChip(text: label(taskStatusLabels, st), color: statusColor(st)),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InfoRow('Người nhận', a == null ? 'Chưa giao' : (a.s('full_name').isEmpty ? a.s('username') : a.s('full_name'))),
            InfoRow('Hạn', fmtDateTime(t.sn('dueAt'))),
            if (t.i('batchId') != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('Lô nuôi', style: theme.textTheme.bodySmall)),
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batchId: t.i('batchId')!))),
                    child: Text(t.s('batchCode')),
                  ),
                ]),
              ),
            if (t.sn('description') != null) ...[const Divider(), Padding(padding: const EdgeInsets.only(top: 8), child: Text(t.s('description')))],
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          // Chỉ NGƯỜI NHẬN việc đang TODO/IN_PROGRESS mới có Gửi minh chứng.
          if (isAssignee && open)
            FilledButton.icon(
              onPressed: () => _submitEvidence(t),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Gửi minh chứng'),
            ),
          if ((isAssignee || canManage) && st == 'TODO')
            OutlinedButton.icon(onPressed: () => _setStatus('IN_PROGRESS'), icon: const Icon(Icons.play_arrow_rounded, size: 18), label: const Text('Bắt đầu')),
          if ((isAssignee || canManage) && st == 'IN_PROGRESS')
            OutlinedButton.icon(onPressed: () => _setStatus('TODO'), icon: const Icon(Icons.undo_rounded, size: 18), label: const Text('Đặt lại Cần làm')),
          if (canManage) OutlinedButton.icon(onPressed: () => _edit(t), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Sửa')),
          if (canManage && (open || st == 'PENDING_REVIEW'))
            OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.block_rounded, size: 18), label: const Text('Hủy việc')),
          if (canManage && (st == 'COMPLETED' || st == 'CANCELLED'))
            OutlinedButton.icon(onPressed: _reopen, icon: const Icon(Icons.restart_alt_rounded, size: 18), label: const Text('Mở lại công việc')),
          // Có lịch sử thì ẩn Xóa, dùng Hủy.
          if (canManage && subs.isEmpty)
            OutlinedButton.icon(onPressed: () => _delete(t), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Xóa')),
        ]),
        const SizedBox(height: 22),
        Text('Lịch sử gửi minh chứng', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        if (subs.isEmpty)
          Text('Chưa có lần gửi nào.', style: theme.textTheme.bodySmall)
        else
          for (final s in subs) _submission(context, t, s),
      ],
    );
  }

  String _person(J s, String idKey, String objKey) {
    final o = s.m(objKey);
    if (o != null) return o.s('full_name').isEmpty ? o.s('username') : o.s('full_name');
    final id = s.i(idKey);
    return id == null ? '—' : 'Người dùng #$id';
  }

  Widget _submission(BuildContext context, J t, J s) {
    final theme = Theme.of(context);
    final ss = s.sn('status');
    final canReview = LocalSession.canManage &&
        t.sn('status') == 'PENDING_REVIEW' &&
        ss == 'PENDING' &&
        s.i('submittedByUserId') != LocalSession.userId; // không tự duyệt, kể cả admin
    final reason = s.sn('reason') ?? s.sn('reviewReason') ?? s.sn('reviewNote');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(fmtDateTime(s.sn('submittedAt')), style: theme.textTheme.titleSmall)),
            StatusChip(text: label(submissionStatusLabels, ss), color: statusColor(ss)),
          ]),
          Text('Gửi bởi ${_person(s, 'submittedByUserId', 'submittedBy')}', style: theme.textTheme.bodySmall),
          if (s.sn('notes') != null) ...[const SizedBox(height: 6), Text(s.s('notes'))],
          const SizedBox(height: 8),
          // Hiển thị SNAPSHOT lúc gửi, không đọc lại nhật ký hiện tại.
          for (final e in s.l('evidence')) _evidence(context, e),
          if (s.sn('reviewedAt') != null) ...[
            const Divider(),
            Text('Duyệt bởi ${_person(s, 'reviewedByUserId', 'reviewedBy')} · ${fmtDateTime(s.sn('reviewedAt'))}',
                style: theme.textTheme.bodySmall),
            if (reason != null) Text('Lý do: $reason', style: theme.textTheme.bodyMedium),
          ],
          if (canReview) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton(onPressed: () => _review(s, true), child: const Text('Duyệt'))),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => _review(s, false),
                  child: const Text('Trả lại'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _evidence(BuildContext context, J e) {
    final theme = Theme.of(context);
    final type = e.sn('type');
    final r = e.m('record') ?? {};
    String body;
    switch (type) {
      case 'CARE_LOG':
        body = '${careActionLabel(r.s('actionType'))}: ${r.s('notes')}';
        break;
      case 'GROWTH_PROGRESS':
        body = '${r.s('stage')}: ${r.s('notes')}';
        break;
      case 'HARVEST':
        body = '${kg(r.d('totalYieldKg'))}${r.sn('qualityGrade') == null ? '' : ' · ${r.s('qualityGrade')}'}';
        break;
      default:
        body = r.toString();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label(evidenceTypeLabels, type), style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(body, style: theme.textTheme.bodyMedium),
        if (r.l('images').isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final i in r.l('images')) NetImage(i.sn('imageUrl'), width: 56, height: 56)]),
        ],
      ]),
    );
  }
}
