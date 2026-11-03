import 'package:image_picker/image_picker.dart';

const _okExt = ['.jpg', '.jpeg', '.png', '.webp'];
const maxImageBytes = 5 * 1024 * 1024; // 5 MiB

/// Kiểm tra ảnh TRƯỚC khi gửi: JPEG/PNG/WebP, ≤5 MiB, số lượng trong [min, max].
/// Trả về thông báo lỗi hoặc null nếu hợp lệ.
Future<String?> validateImages(List<XFile> files, {int min = 0, int max = 5}) async {
  if (files.length < min) return 'Chọn ít nhất $min ảnh.';
  if (files.length > max) return 'Tối đa $max ảnh mỗi lần.';
  for (final f in files) {
    final n = f.name.toLowerCase();
    if (!_okExt.any(n.endsWith)) return '"${f.name}" không phải JPEG/PNG/WebP.';
    if (await f.length() > maxImageBytes) return '"${f.name}" vượt quá 5 MiB.';
    if (f.name.length > 255) return 'Tên file quá dài (tối đa 255 ký tự).';
  }
  return null;
}
