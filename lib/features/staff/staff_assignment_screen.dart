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
  final String path;
  final String title;
  final int? facilityId;
  @override
  State<StaffAssignmentScreen> createState() => _StaffAssignmentScreenState();
}

class _StaffAssignmentScreenState extends State<StaffAssignmentScreen> {
  final _key = GlobalKey<PagedListViewState>();
  Future<void> _add() async {
    final selection = await pickOneFrom(
      context,
      PickerSource(
        title: 'Chọn nhân viên',
        fetch: (page, search) async {
          final response = await FarmApi.instance.get(
            widget.facilityId == null
                ? '/admin/users'
                : '/production-facilities/${widget.facilityId}/staff',
            query: {
              'page': page,
              'limit': 20,
              if (widget.facilityId == null) 'role': 'staff',
              'search': search,
            },
          );
          if (widget.facilityId != null)
            response['data'] = response
                .l('data')
                .map((item) => item.m('user')!)
                .toList();
          return PageData.from(response);
        },
        label: (item) {
          final user = item.m('user') ?? item;
          return user.s('full_name').isEmpty
              ? user.s('username')
              : user.s('full_name');
        },
        subtitle: (item) => (item.m('user') ?? item).s('username'),
      ),
    );
    if (selection == null || selection.isEmpty) return;
    try {
      await FarmApi.instance.post(widget.path, {
        'userId': selection.first['id'],
      });
      _key.currentState?.load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
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
      _key.currentState?.load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
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
