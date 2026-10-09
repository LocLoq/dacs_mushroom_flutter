import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/json_utils.dart';
import 'async_views.dart';

/// Danh sách phân trang phía server (specs/UI_DESIGN_SPEC.md §4):
///  - search chỉ gọi API khi Enter/Done, xoá search bỏ lọc ngay
///  - đổi [deps] (bộ lọc) thì về trang 1
///  - kết quả của truy vấn cũ đến muộn bị bỏ qua
///  - nút Trước/Sau bị khoá khi đang tải hoặc hết trang
class PagedListView extends StatefulWidget {
  final Future<PageData> Function(int page, String search) fetch;
  final Widget Function(BuildContext context, J item, VoidCallback reload) itemBuilder;
  final String? searchHint;
  final Widget? header;
  final String emptyText;
  final List<Object?> deps;
  final EdgeInsets padding;

  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.searchHint,
    this.header,
    this.emptyText = 'Chưa có dữ liệu.',
    this.deps = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 16),
  });

  @override
  State<PagedListView> createState() => PagedListViewState();
}

class PagedListViewState extends State<PagedListView> {
  final _searchCtrl = TextEditingController();
  PageData _data = PageData.empty;
  int _page = 1;
  String _search = '';
  bool _loading = true;
  String? _error;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PagedListView old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.deps, widget.deps)) {
      _page = 1;
      load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Tải lại trang hiện tại (giữ query).
  Future<void> load() async {
    final my = ++_ticket;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.fetch(_page, _search);
      if (!mounted || my != _ticket) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || my != _ticket) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _go(int page) {
    _page = page;
    load();
  }

  void _submitSearch() {
    _search = _searchCtrl.text.trim();
    _go(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = _data.totalPages < 1 ? 1 : _data.totalPages;

    Widget body;
    if (_loading && _data.items.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _data.items.isEmpty) {
      body = ErrorView(message: _error!, onRetry: load);
    } else if (_data.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [SizedBox(height: 240, child: EmptyView(widget.emptyText))]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: load,
        child: ListView.separated(
          padding: widget.padding,
          itemCount: _data.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c, i) => widget.itemBuilder(c, _data.items[i], load),
        ),
      );
    }

    return Column(
      children: [
        if (widget.searchHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              onChanged: (v) {
                setState(() {});
                if (v.isEmpty && _search.isNotEmpty) _submitSearch(); // xoá search -> bỏ lọc ngay
              },
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _submitSearch();
                        },
                      ),
              ),
            ),
          ),
        if (widget.header != null) widget.header!,
        Expanded(
          child: Stack(
            children: [
              body,
              if (_loading && _data.items.isNotEmpty)
                const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: (_loading || _page <= 1) ? null : () => _go(_page - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Trang $_page/$totalPages · ${_data.totalItems} mục', style: theme.textTheme.bodySmall),
              IconButton(
                onPressed: (_loading || _page >= _data.totalPages) ? null : () => _go(_page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
