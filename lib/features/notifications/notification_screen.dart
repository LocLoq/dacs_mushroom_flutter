import 'package:flutter/material.dart';
import '../../core/network/farm_api.dart';
import '../../core/services/workflow_refresh_service.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/paged_list.dart';
import '../tasks/task_detail_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context) => !LocalSession.isLoggedIn
      ? const SizedBox.shrink()
      : ValueListenableBuilder<int>(
          valueListenable: WorkflowRefreshService.instance.unreadCount,
          builder: (context, count, _) => IconButton(
            tooltip: 'Thông báo',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        );
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _key = GlobalKey<PagedListViewState>();
  Future<void> _readAll() async {
    try {
      await FarmApi.instance.post('/notifications/read-all');
      WorkflowRefreshService.instance.invalidate('notifications');
      _key.currentState?.load();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> _open(J item) async {
    try {
      await FarmApi.instance.patch('/notifications/${item.s('id')}/read', {});
      WorkflowRefreshService.instance.invalidate('notifications');
      final taskId = item.sn('taskId');
      if (taskId != null) {
        await FarmApi.instance.get('/dashboard/tasks/$taskId');
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
        );
      }
      _key.currentState?.load();
    } on ApiException catch (e) {
      if (mounted)
        toast(
          context,
          e.isForbidden
              ? 'Bạn không còn quyền truy cập công việc này.'
              : e.message,
          error: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo'),
      actions: [
        TextButton(onPressed: _readAll, child: const Text('Đọc tất cả')),
      ],
    ),
    body: PagedListView(
      key: _key,
      refreshResources: const ['notifications'],
      emptyText: 'Chưa có thông báo.',
      fetch: (page, _) async {
        final response = await WorkflowRefreshService.instance
            .loadNotifications(page: page);
        return PageData.from(response);
      },
      itemBuilder: (context, item, _) => ListTile(
        leading: Icon(
          item['readAt'] == null
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
        ),
        title: Text(
          item.s('title'),
          style: TextStyle(
            fontWeight: item['readAt'] == null
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Text(fmtDateTime(item.sn('createdAt'))),
        onTap: () => _open(item),
      ),
    ),
  );
}
