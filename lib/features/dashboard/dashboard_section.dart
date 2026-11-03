import 'package:flutter/material.dart';

import '../../core/network/farm_api.dart';
import '../../core/storage/local_session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_chip.dart';
import '../batches/batch_detail_screen.dart';
import '../batches/batch_list_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_list_screen.dart';

/// Tổng quan (specs/S02_DASHBOARD.md). Ba vùng tải độc lập: lỗi một vùng không che vùng khác.
/// Staff KHÔNG gọi API reports.
class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = FarmApi.instance;
    final now = DateTime.now();
    final canManage = LocalSession.canManage;

    Widget kpi(String t, String v, IconData icon) => SizedBox(
          width: 156,
          child: SoftCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(v, style: theme.textTheme.titleLarge),
              Text(t, style: theme.textTheme.bodySmall),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── KPI ──
      if (canManage)
        SizedBox(
          child: FutureBody<J>(
            load: () async => (await api.get('/reports/overview',
                    query: {'from': '${now.year}-01-01', 'to': ymd(now), 'groupBy': 'month'}))
                .m('data') ??
                {},
            builder: (ctx, d, _) {
              final c = d.m('cultivation') ?? {};
              final sb = c.m('statusBreakdown') ?? {};
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  kpi('Số lô (năm nay)', '${c.i('batchCount') ?? 0}', Icons.eco_rounded),
                  kpi('Sản lượng thu hoạch', kg(c.d('totalHarvestKg')), Icons.scale_rounded),
                  kpi('Cơ sở', '${c.i('facilities') ?? 0}', Icons.factory_rounded),
                  kpi('Lô trễ hạn', '${c.i('overdueBatches') ?? 0}', Icons.schedule_rounded),
                ]),
                if (sb.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in sb.entries)
                      ActionChip(
                        label: Text('${label(batchStatusLabels, e.key)} ${(e.value as Map)['count'] ?? 0}'),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => BatchListScreen(initialStatus: e.key))),
                      ),
                  ]),
                ],
              ]);
            },
          ),
        ),
      if (canManage) const SizedBox(height: 18),

      // ── Việc cần làm ──
      FutureBody<J>(
        load: () => api.get('/dashboard/tasks', query: {'page': 1, 'limit': 5}),
        builder: (ctx, r, _) {
          final page = PageData.from(r);
          return _panel(
            context,
            // totalItems của truy vấn mặc định: TODO + IN_PROGRESS + PENDING_REVIEW
            title: 'Việc cần làm (${page.totalItems})',
            action: 'Xem tất cả',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskListScreen())),
            empty: 'Không có việc đang mở.',
            children: [
              for (final t in page.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(t.s('title'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Hạn ${fmtDate(t.sn('dueAt'))}'),
                  trailing: StatusChip(text: label(taskStatusLabels, t.sn('status')), color: statusColor(t.sn('status'))),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.s('id')))),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),

      // ── Lô gần nhất ──
      FutureBody<J>(
        load: () => api.get('/cultivation-batches', query: {'page': 1, 'limit': 5}),
        builder: (ctx, r, _) {
          final page = PageData.from(r);
          return _panel(
            context,
            // Staff không có KPI từ reports: dùng tổng số lô từ pagination.
            title: canManage ? 'Lô gần nhất' : 'Lô nuôi (${page.totalItems})',
            action: 'Quản lý lô',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatchListScreen())),
            empty: 'Chưa có lô nào.',
            children: [
              for (final b in page.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(b.s('batchCode')),
                  subtitle: Text('${b.m('mushroom')?.s('commonName') ?? '—'} · ${fmtDate(b.sn('startDate'))}'),
                  trailing: StatusChip(text: label(batchStatusLabels, b.sn('status')), color: statusColor(b.sn('status'))),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batchId: b.i('id')!))),
                ),
            ],
          );
        },
      ),
    ]);
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required String action,
    required VoidCallback onAction,
    required String empty,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          TextButton(onPressed: onAction, child: Text(action)),
        ]),
        if (children.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(empty, style: theme.textTheme.bodySmall)) else ...children,
      ]),
    );
  }
}
