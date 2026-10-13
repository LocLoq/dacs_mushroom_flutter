import 'package:flutter/material.dart';
import '../../core/network/farm_api.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/paged_list.dart';

class StaffAssignmentScreen extends StatefulWidget {
  const StaffAssignmentScreen({
    super.key,
    required this.path,
    required this.title,
    this.facilityId,
  });
  final String path, title;
  final int? facilityId;
  @override
  State<StaffAssignmentScreen> createState() => _StaffAssignmentScreenState();
}

class _StaffAssignmentScreenState extends State<StaffAssignmentScreen> {
  final _key = GlobalKey<PagedListViewState>();
  bool _adding = false;
  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    int addedCount = 0;
    try {
      final selected = await pickManyFrom(
        context,
        PickerSource(
          title: 'Chọn nhân viên',
          emptyText: 'Không còn nhân viên đủ điều kiện để thêm.',
          fetch: (page, search) async => PageData.from(
            await FarmApi.instance.get(
              widget.path,
              query: {
                'available': true,
                'page': page,
                'limit': 20,
                'search': search,
              },
            ),
          ),
          label: (item) => item.s('full_name').isEmpty
              ? item.s('username')
              : item.s('full_name'),
          subtitle: (item) => item.s('username'),
        ),
        maxSelected: 100,
        onConfirm: (selection) async {
          final response = await FarmApi.instance.post(widget.path, {
            'userIds': selection.map((item) => item.i('id')).toList(),
          });
          addedCount = response.i('addedCount') ?? 0;
          await _key.currentState?.load();
        },
      );
      if (mounted && selected != null)
        toast(
          context,
          addedCount > 0
              ? 'Đã thêm $addedCount nhân viên.'
              : 'Danh sách phân công đã được cập nhật.',
        );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(J item) async {
    final ok = await confirmDialog(
      context,
      title: 'Thu hồi quyền?',
      message:
          'Nhân viên sẽ mất quyền thao tác. Công việc và lịch sử được giữ lại.',
    );
    if (!ok) return;
    try {
      await FarmApi.instance.delete('${widget.path}/${item.i('userId')}');
      await _key.currentState?.load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _adding ? null : _add,
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Thêm nhân viên'),
    ),
    body: PagedListView(
      key: _key,
      refreshResources: const ['permissions'],
      emptyText: 'Chưa có nhân viên được phân công.',
      fetch: (page, _) async => PageData.from(
        await FarmApi.instance.get(
          widget.path,
          query: {'page': page, 'limit': 20},
        ),
      ),
      itemBuilder: (context, item, _) => ListTile(
        title: Text(item.m('user')?.s('full_name') ?? ''),
        subtitle: Text(item.m('user')?.s('username') ?? ''),
        trailing: IconButton(
          tooltip: 'Thu hồi quyền',
          icon: const Icon(Icons.person_remove_outlined),
          onPressed: () => _remove(item),
        ),
      ),
    ),
  );
}
