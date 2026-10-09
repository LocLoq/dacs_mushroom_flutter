/// Tiện ích đọc JSON gọn hơn. Mọi model trong khu "Quản lý" dùng Map thay vì
/// class riêng, vì contract (specs/API_CONTRACT.md) có nhiều field tuỳ chọn.
typedef J = Map<String, dynamic>;

extension JsonRead on Map<String, dynamic> {
  /// Chuỗi, rỗng nếu null.
  String s(String k) => this[k] == null ? '' : this[k].toString();

  /// Chuỗi hoặc null (null/rỗng -> null).
  String? sn(String k) {
    final v = this[k];
    if (v == null) return null;
    final t = v.toString();
    return t.isEmpty ? null : t;
  }

  int? i(String k) {
    final v = this[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  double? d(String k) {
    final v = this[k];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  J? m(String k) {
    final v = this[k];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  List<J> l(String k) {
    final v = this[k];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

/// Một trang dữ liệu theo envelope { data: [], pagination: {...} }.
class PageData {
  final List<J> items;
  final int page;
  final int totalPages;
  final int totalItems;

  const PageData(this.items, this.page, this.totalPages, this.totalItems);

  static const empty = PageData([], 1, 0, 0);

  factory PageData.from(J resp) {
    final p = resp.m('pagination') ?? {};
    return PageData(
      resp.l('data'),
      p.i('currentPage') ?? 1,
      p.i('totalPages') ?? 0,
      p.i('totalItems') ?? 0,
    );
  }
}
