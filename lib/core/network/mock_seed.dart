import '../utils/json_utils.dart';

/// Dữ liệu khởi tạo cho chế độ mẫu. Ngày tháng tính tương đối theo hôm nay
/// để màn Tổng quan/Báo cáo luôn có số liệu "gần đây".
String isoAgo({int days = 0, int hours = 0}) =>
    DateTime.now().toUtc().subtract(Duration(days: days, hours: hours)).toIso8601String();

String isoAhead({int days = 0}) => DateTime.now().toUtc().add(Duration(days: days)).toIso8601String();

class MockSeed {
  static const roles = <(int, String)>[(1, 'admin'), (2, 'manager'), (3, 'staff')];

  static List<J> species() => [
        _sp(1, 'Nấm Rơm', 'Volvariella volvacea', 'Pluteaceae', 'Volvariella', 'EDIBLE', 'EASY', 'SAPROBIC',
            'Rơm rạ mục, nơi ẩm nóng', 'Mùa hè'),
        _sp(2, 'Nấm Bào Ngư', 'Pleurotus ostreatus', 'Pleurotaceae', 'Pleurotus', 'CHOICE', 'EASY', 'SAPROBIC',
            'Thân gỗ mục', 'Quanh năm'),
        _sp(3, 'Nấm Linh Chi', 'Ganoderma lucidum', 'Ganodermataceae', 'Ganoderma', 'INEDIBLE', 'MEDIUM', 'SAPROBIC',
            'Gốc cây gỗ cứng', 'Mùa mưa'),
        _sp(4, 'Mộc Nhĩ', 'Auricularia auricula-judae', 'Auriculariaceae', 'Auricularia', 'EDIBLE', 'EASY', 'SAPROBIC',
            'Cành cây mục', 'Quanh năm'),
        _sp(5, 'Nấm Mỡ', 'Agaricus bisporus', 'Agaricaceae', 'Agaricus', 'CHOICE', 'MEDIUM', 'SAPROBIC',
            'Phân ủ hoai', 'Mùa lạnh'),
        _sp(6, 'Nấm Đùi Gà', 'Pleurotus eryngii', 'Pleurotaceae', 'Pleurotus', 'CHOICE', 'MEDIUM', 'SAPROBIC',
            'Mùn cưa giàu dinh dưỡng', 'Mùa mát'),
        _sp(7, 'Nấm Kim Châm', 'Flammulina velutipes', 'Physalacriaceae', 'Flammulina', 'CHOICE', 'MEDIUM', 'SAPROBIC',
            'Gỗ mục vùng lạnh', 'Mùa đông'),
        _sp(8, 'Nấm Hương', 'Lentinula edodes', 'Omphalotaceae', 'Lentinula', 'CHOICE', 'HARD', 'SAPROBIC',
            'Gỗ sồi, dẻ', 'Mùa thu'),
        _sp(9, 'Nấm Tử Thần', 'Amanita phalloides', 'Amanitaceae', 'Amanita', 'DEADLY', 'UNCULTIVABLE', 'MYCORRHIZAL',
            'Rừng sồi, dẻ', 'Mùa thu'),
      ];

  static J _sp(int id, String name, String sci, String fam, String genus, String edi, String diff, String eco,
          String habitat, String season) =>
      {
        'id': id,
        'commonName': name,
        'scientificName': sci,
        'family': fam,
        'genus': genus,
        'edibilityStatus': edi,
        'cultivationDifficulty': diff,
        'ecologyType': eco,
        'otherNames': null,
        'habitat': habitat,
        'fruitingSeason': season,
        'capDescription': edi == 'DEADLY' ? 'Mũ xanh ô liu, nhẵn, có thể ngả vàng' : 'Mũ tròn, màu từ trắng ngà đến nâu',
        'gillsDescription': 'Phiến xếp khít, màu trắng đến kem',
        'stemDescription': 'Thân hình trụ, chắc, có thể có vòng thân',
        'sporePrintColor': 'Trắng',
        'bruisingBehavior': null,
        'toxicitySymptoms': edi == 'DEADLY' ? 'Nôn, tiêu chảy dữ dội, tổn thương gan thận, có thể tử vong' : null,
        'medicinalProperties': name == 'Nấm Linh Chi' ? 'Dùng trong y học cổ truyền' : null,
      };

  static List<J> facilities() => [
        {
          'id': 1,
          'name': 'Trại Nấm Đà Lạt Xanh',
          'address': '12 Đường Hồ Xuân Hương, Phường 9',
          'province': 'Lâm Đồng',
          'facilityType': 'ENTERPRISE',
          'status': 'ACTIVE',
          'taxCode': '5801234567',
          'contactPhone': '0263 3822 111',
          'contactEmail': 'lienhe@dalatxanh.vn',
          'capacityTonsPerYear': 120.0,
          'totalAreaSqm': 3500.0,
          'certifications': 'VietGAP',
          'mushroom_ids': [1, 2, 7, 8],
        },
        {
          'id': 2,
          'name': 'HTX Nấm Đơn Dương',
          'address': 'Thôn 3, Xã Lạc Lâm, Huyện Đơn Dương',
          'province': 'Lâm Đồng',
          'facilityType': 'COOPERATIVE',
          'status': 'ACTIVE',
          'taxCode': '5809876543',
          'contactPhone': '0263 3855 222',
          'contactEmail': null,
          'capacityTonsPerYear': 60.0,
          'totalAreaSqm': 1800.0,
          'certifications': null,
          'mushroom_ids': [3, 4, 6],
        },
        {
          'id': 3,
          'name': 'Hộ Nguyễn Văn An',
          'address': 'Số 5 Hẻm 20, Phường 3',
          'province': 'Lâm Đồng',
          'facilityType': 'HOUSEHOLD',
          'status': 'ACTIVE',
          'taxCode': null,
          'contactPhone': '0905 123 456',
          'contactEmail': null,
          'capacityTonsPerYear': 8.0,
          'totalAreaSqm': 220.0,
          'certifications': null,
          'mushroom_ids': [2, 4, 5],
        },
        {
          'id': 4,
          'name': 'Trại Nấm Bảo Lộc',
          'address': 'Quốc lộ 20, Phường Lộc Sơn, Bảo Lộc',
          'province': 'Lâm Đồng',
          'facilityType': 'ENTERPRISE',
          'status': 'SUSPENDED',
          'taxCode': '5805551234',
          'contactPhone': '0263 3866 333',
          'contactEmail': 'baoloc@nam.vn',
          'capacityTonsPerYear': 40.0,
          'totalAreaSqm': 1200.0,
          'certifications': null,
          'mushroom_ids': [1],
        },
      ];

  /// (id, mã lô, cơ sở, giống, trạng thái, bắt đầu cách đây N ngày, dự kiến thu hoạch sau N ngày, số bịch, giá thể)
  static const batchRows = <(int, String, int, int, String, int, int, int, String)>[
    (1, 'LO-2026-001', 1, 2, 'HARVESTING', 45, -3, 500, 'Mùn cưa cao su'),
    (2, 'LO-2026-002', 1, 1, 'FRUITING', 30, 5, 800, 'Rơm rạ'),
    (3, 'LO-2026-003', 2, 4, 'INCUBATION', 20, 15, 1200, 'Mùn cưa + cám gạo'),
    (4, 'LO-2026-004', 2, 3, 'PREPARATION', 3, 60, 300, 'Gỗ sồi'),
    (5, 'LO-2026-005', 3, 5, 'COMPLETED', 90, -30, 400, 'Phân ủ hoai'),
    (6, 'LO-2026-006', 3, 2, 'FAILED', 70, -20, 600, 'Mùn cưa'),
    (7, 'LO-2026-007', 1, 7, 'INCUBATION', 14, 25, 700, 'Mùn cưa + bã mía'),
    (8, 'LO-2026-008', 1, 8, 'FRUITING', 55, -10, 350, 'Mùn cưa sồi'),
    (9, 'LO-2026-009', 2, 6, 'HARVESTING', 38, 4, 450, 'Mùn cưa + cám'),
    (10, 'LO-2026-010', 4, 1, 'COMPLETED', 120, -60, 1000, 'Rơm rạ'),
    (11, 'LO-2026-011', 3, 4, 'PREPARATION', 1, 70, 500, 'Mùn cưa'),
    (12, 'LO-2026-012', 1, 2, 'COMPLETED', 100, -40, 650, 'Mùn cưa cao su'),
  ];

  static List<J> users() => [
        {'id': 1, 'username': 'admin', 'full_name': 'Quản trị viên', 'email': 'admin@trainam.vn', 'phone_number': '0900000001', 'role_id': 1},
        {'id': 2, 'username': 'manager', 'full_name': 'Trần Quản Lý', 'email': 'quanly@trainam.vn', 'phone_number': '0900000002', 'role_id': 2},
        {'id': 3, 'username': 'staff', 'full_name': 'Lê Nhân Viên', 'email': 'nhanvien@trainam.vn', 'phone_number': '0900000003', 'role_id': 3},
        {'id': 4, 'username': 'nhanvien2', 'full_name': 'Phạm Thị Hoa', 'email': 'hoa@trainam.vn', 'phone_number': '0900000004', 'role_id': 3},
        {'id': 5, 'username': 'quanly2', 'full_name': 'Võ Minh Tâm', 'email': 'tam@trainam.vn', 'phone_number': '0900000005', 'role_id': 2},
      ];

  static const passwords = <int, String>{1: 'admin123', 2: 'manager123', 3: 'staff123', 4: 'password123', 5: 'password123'};
}
