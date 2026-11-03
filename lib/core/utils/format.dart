import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

const _empty = 'Chưa có dữ liệu';

String _two(int n) => n.toString().padLeft(2, '0');

DateTime? parseIso(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso)?.toLocal();
}

/// dd/MM/yyyy theo giờ địa phương của thiết bị.
String fmtDate(String? iso) {
  final t = parseIso(iso);
  if (t == null) return '—';
  return '${_two(t.day)}/${_two(t.month)}/${t.year}';
}

String fmtDateTime(String? iso) {
  final t = parseIso(iso);
  if (t == null) return '—';
  return '${_two(t.day)}/${_two(t.month)}/${t.year} ${_two(t.hour)}:${_two(t.minute)}';
}

/// YYYY-MM-DD (dùng cho query báo cáo).
String ymd(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

/// Tiền VND từ chuỗi Decimal của server. KHÔNG đi qua double nên không mất chữ số.
String vnd(String? dec) {
  if (dec == null || dec.isEmpty) return _empty;
  var s = dec.trim();
  var neg = false;
  if (s.startsWith('-')) {
    neg = true;
    s = s.substring(1);
  }
  final parts = s.split('.');
  final intPart = parts[0].isEmpty ? '0' : parts[0];
  var frac = parts.length > 1 ? parts[1] : '';
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final buf = StringBuffer();
  for (var k = 0; k < intPart.length; k++) {
    if (k > 0 && (intPart.length - k) % 3 == 0) buf.write('.');
    buf.write(intPart[k]);
  }
  return '${neg ? '-' : ''}$buf${frac.isEmpty ? '' : ',$frac'} ₫';
}

/// Số thực thu hoạch (kg): bỏ .0 thừa.
String kg(num? v) {
  if (v == null) return _empty;
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  return '$s kg';
}

/// 0–1 -> %.
String pct01(num? v) {
  if (v == null || v.isNaN || v < 0 || v > 1) return _empty;
  return '${(v * 100).round()}%';
}

// ───────────── Nhãn & màu theo enum của backend ─────────────

const batchStatusLabels = {
  'PREPARATION': 'Chuẩn bị',
  'INCUBATION': 'Ủ tơ',
  'FRUITING': 'Ra quả thể',
  'HARVESTING': 'Thu hoạch',
  'COMPLETED': 'Hoàn thành',
  'FAILED': 'Thất bại',
};

const taskStatusLabels = {
  'TODO': 'Cần làm',
  'IN_PROGRESS': 'Đang thực hiện',
  'PENDING_REVIEW': 'Chờ duyệt',
  'COMPLETED': 'Hoàn thành',
  'CANCELLED': 'Đã hủy',
};

const submissionStatusLabels = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Đã trả lại',
  'CANCELLED': 'Đã hủy',
};

const facilityTypeLabels = {
  'HOUSEHOLD': 'Hộ gia đình',
  'COOPERATIVE': 'Hợp tác xã',
  'ENTERPRISE': 'Doanh nghiệp',
};

const facilityStatusLabels = {
  'ACTIVE': 'Hoạt động',
  'SUSPENDED': 'Tạm ngưng',
  'CLOSED': 'Đã đóng',
};

const edibilityLabels = {
  'CHOICE': 'Ăn ngon',
  'EDIBLE': 'Ăn được',
  'INEDIBLE': 'Không ăn được',
  'POISONOUS': 'Có độc',
  'DEADLY': 'Cực độc',
};

const difficultyLabels = {
  'EASY': 'Dễ',
  'MEDIUM': 'Trung bình',
  'HARD': 'Khó',
  'UNCULTIVABLE': 'Chưa nuôi trồng được',
};

const ecologyLabels = {
  'SAPROBIC': 'Hoại sinh',
  'MYCORRHIZAL': 'Cộng sinh rễ',
  'PARASITIC': 'Ký sinh',
};

const expenseCategoryLabels = {
  'MATERIAL': 'Vật tư',
  'TOOL': 'Dụng cụ',
  'FERTILIZER': 'Phân bón',
  'OTHER': 'Khác',
};

const classifierStatusLabels = {
  'QUEUED': 'Đang chờ',
  'PROCESSING': 'Đang xử lý',
  'SUCCEEDED': 'Thành công',
  'FAILED': 'Thất bại',
};

const classifierEdibilityLabels = {
  'POISONOUS': 'Có độc',
  'NON_POISONOUS': 'Không độc',
  'UNKNOWN': 'Chưa xác định',
};

const roleLabels = {'admin': 'Quản trị viên', 'manager': 'Quản lý', 'staff': 'Nhân viên'};

const evidenceTypeLabels = {
  'CARE_LOG': 'Chăm sóc',
  'GROWTH_PROGRESS': 'Sinh trưởng',
  'HARVEST': 'Thu hoạch',
};

/// Nhãn đã biết thì dịch, mã lạ giữ nguyên.
String label(Map<String, String> map, String? code) {
  if (code == null || code.isEmpty) return '—';
  return map[code] ?? code;
}

/// Giá trị cũ "WATERING" của care log được dịch, còn lại là chuỗi tự do.
String careActionLabel(String a) => a == 'WATERING' ? 'Tưới nước' : a;

Color statusColor(String? code) {
  switch (code) {
    case 'COMPLETED':
    case 'APPROVED':
    case 'SUCCEEDED':
    case 'SUCCESS':
    case 'ACTIVE':
    case 'NON_POISONOUS':
      return AppColors.success;
    case 'FAILED':
    case 'FAILURE':
    case 'REJECTED':
    case 'POISONOUS':
    case 'DEADLY':
    case 'CLOSED':
      return AppColors.danger;
    case 'PENDING_REVIEW':
    case 'PENDING':
    case 'SUSPENDED':
    case 'HARVESTING':
    case 'UNKNOWN':
      return AppColors.warning;
    case 'CANCELLED':
      return const Color(0xFF7A867A);
    default:
      return AppColors.primary;
  }
}
