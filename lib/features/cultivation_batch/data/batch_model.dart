// Khớp với model Prisma `CultivationBatch` / enum `BatchStatus` phía backend.
enum BatchStatus { preparation, incubation, fruiting, harvesting, completed, failed }

class BatchModel {
  final String id;
  final String batchCode; // batch_code (unique)

  // Khóa ngoại (mock: lưu tên hiển thị thay vì id quan hệ thật)
  final String facilityId;
  final String facilityName;
  final String mushroomId;
  final String mushroomName;

  BatchStatus status;
  final String? substrateType; // substrate_type
  final String? spawnSource; // spawn_source
  final int? bagQuantity; // bag_quantity

  final DateTime startDate; // start_date
  final DateTime? expectedHarvestDate; // expected_harvest_date
  final DateTime? endDate; // end_date

  final double? actualYieldKg; // actual_yield_kg
  final double? defectRate; // defect_rate (%)
  final String? notes;

  BatchModel({
    required this.id,
    required this.batchCode,
    required this.facilityId,
    required this.facilityName,
    required this.mushroomId,
    required this.mushroomName,
    required this.status,
    this.substrateType,
    this.spawnSource,
    this.bagQuantity,
    required this.startDate,
    this.expectedHarvestDate,
    this.endDate,
    this.actualYieldKg,
    this.defectRate,
    this.notes,
  });

  BatchModel copyWith({
    String? batchCode,
    String? facilityId,
    String? facilityName,
    String? mushroomId,
    String? mushroomName,
    BatchStatus? status,
    String? substrateType,
    String? spawnSource,
    int? bagQuantity,
    DateTime? startDate,
    DateTime? expectedHarvestDate,
    DateTime? endDate,
    double? actualYieldKg,
    double? defectRate,
    String? notes,
  }) {
    return BatchModel(
      id: id,
      batchCode: batchCode ?? this.batchCode,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      mushroomId: mushroomId ?? this.mushroomId,
      mushroomName: mushroomName ?? this.mushroomName,
      status: status ?? this.status,
      substrateType: substrateType ?? this.substrateType,
      spawnSource: spawnSource ?? this.spawnSource,
      bagQuantity: bagQuantity ?? this.bagQuantity,
      startDate: startDate ?? this.startDate,
      expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
      endDate: endDate ?? this.endDate,
      actualYieldKg: actualYieldKg ?? this.actualYieldKg,
      defectRate: defectRate ?? this.defectRate,
      notes: notes ?? this.notes,
    );
  }

  // TODO(BACKEND): factory BatchModel.fromJson(Map<String, dynamic> json) => BatchModel(
  //   id: json['id'].toString(),
  //   batchCode: json['batch_code'],
  //   facilityId: json['facility_id'].toString(),
  //   facilityName: json['facility']?['name'] ?? '',
  //   mushroomId: json['mushroom_id'].toString(),
  //   mushroomName: json['mushroom']?['name'] ?? '',
  //   status: BatchStatus.values.byName(json['status'].toString().toLowerCase()),
  //   substrateType: json['substrate_type'],
  //   spawnSource: json['spawn_source'],
  //   bagQuantity: json['bag_quantity'],
  //   startDate: DateTime.parse(json['start_date']),
  //   expectedHarvestDate: json['expected_harvest_date'] != null ? DateTime.parse(json['expected_harvest_date']) : null,
  //   endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
  //   actualYieldKg: (json['actual_yield_kg'] as num?)?.toDouble(),
  //   defectRate: (json['defect_rate'] as num?)?.toDouble(),
  //   notes: json['notes'],
  // );
  //
  // Map<String, dynamic> toJson() => {
  //   'batch_code': batchCode,
  //   'facility_id': int.parse(facilityId),
  //   'mushroom_id': int.parse(mushroomId),
  //   'status': status.name.toUpperCase(),
  //   'substrate_type': substrateType,
  //   'spawn_source': spawnSource,
  //   'bag_quantity': bagQuantity,
  //   'start_date': startDate.toIso8601String(),
  //   'expected_harvest_date': expectedHarvestDate?.toIso8601String(),
  //   'end_date': endDate?.toIso8601String(),
  //   'actual_yield_kg': actualYieldKg,
  //   'defect_rate': defectRate,
  //   'notes': notes,
  // };
}

// ------ Mock data (thay bằng dữ liệu thật từ ApiClient) ------
final mockBatches = [
  BatchModel(
    id: '1',
    batchCode: 'B-2026-001',
    facilityId: '1',
    facilityName: 'Trại nấm Đơn Dương',
    mushroomId: '1',
    mushroomName: 'Nấm Bào Ngư',
    status: BatchStatus.fruiting,
    substrateType: 'Mùn cưa cao su',
    spawnSource: 'Trại giống Bảo Lộc',
    bagQuantity: 2000,
    startDate: DateTime(2026, 7, 1),
    expectedHarvestDate: DateTime(2026, 9, 15),
    notes: 'Theo dõi độ ẩm hàng ngày, tơ lan đều.',
  ),
  BatchModel(
    id: '2',
    batchCode: 'B-2026-002',
    facilityId: '1',
    facilityName: 'Trại nấm Đơn Dương',
    mushroomId: '2',
    mushroomName: 'Nấm Linh Chi',
    status: BatchStatus.incubation,
    substrateType: 'Mùn cưa keo',
    spawnSource: 'Tự nhân giống',
    bagQuantity: 1200,
    startDate: DateTime(2026, 8, 10),
    expectedHarvestDate: DateTime(2026, 11, 1),
  ),
  BatchModel(
    id: '3',
    batchCode: 'B-2026-003',
    facilityId: '2',
    facilityName: 'Trại nấm Đức Trọng',
    mushroomId: '3',
    mushroomName: 'Nấm Rơm',
    status: BatchStatus.harvesting,
    substrateType: 'Rơm rạ ủ',
    spawnSource: 'Trại giống Bảo Lộc',
    bagQuantity: 800,
    startDate: DateTime(2026, 8, 20),
    expectedHarvestDate: DateTime(2026, 9, 5),
    actualYieldKg: 145.5,
    defectRate: 4.2,
  ),
  BatchModel(
    id: '4',
    batchCode: 'B-2026-004',
    facilityId: '3',
    facilityName: 'Trại nấm Lạc Dương',
    mushroomId: '1',
    mushroomName: 'Nấm Bào Ngư',
    status: BatchStatus.failed,
    substrateType: 'Mùn cưa cao su',
    spawnSource: 'Trại giống Bảo Lộc',
    bagQuantity: 500,
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 25),
    defectRate: 100,
    notes: 'Nhiễm mốc xanh toàn trại, đã tiêu hủy.',
  ),
  BatchModel(
    id: '5',
    batchCode: 'B-2025-088',
    facilityId: '1',
    facilityName: 'Trại nấm Đơn Dương',
    mushroomId: '1',
    mushroomName: 'Nấm Bào Ngư',
    status: BatchStatus.completed,
    substrateType: 'Mùn cưa cao su',
    spawnSource: 'Trại giống Bảo Lộc',
    bagQuantity: 1800,
    startDate: DateTime(2025, 11, 1),
    expectedHarvestDate: DateTime(2026, 1, 10),
    endDate: DateTime(2026, 1, 20),
    actualYieldKg: 612.0,
    defectRate: 6.5,
  ),
];
