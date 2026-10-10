// Khớp với model Prisma `CultivationBatch` / enum `BatchStatus` phía backend.
enum BatchStatus {
  preparation,
  incubation,
  fruiting,
  harvesting,
  completed,
  failed,
}

class BatchModel {
  final String id;
  final String batchCode; // batch_code (unique)

  // Khóa ngoại và tên từ quan hệ backend.
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

  factory BatchModel.fromJson(Map<String, dynamic> json) => BatchModel(
    id: json['id'].toString(),
    batchCode: json['batchCode'] as String,
    facilityId: json['facilityId'].toString(),
    facilityName: (json['facility'] as Map?)?['name']?.toString() ?? '',
    mushroomId: json['mushroomId'].toString(),
    mushroomName: (json['mushroom'] as Map?)?['commonName']?.toString() ?? '',
    status: BatchStatus.values.byName((json['status'] as String).toLowerCase()),
    substrateType: json['substrateType'] as String?,
    spawnSource: json['spawnSource'] as String?,
    bagQuantity: (json['bagQuantity'] as num?)?.toInt(),
    startDate: DateTime.parse(json['startDate'] as String),
    expectedHarvestDate: json['expectedHarvestDate'] == null
        ? null
        : DateTime.parse(json['expectedHarvestDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate'] as String),
    actualYieldKg: (json['actualYieldKg'] as num?)?.toDouble(),
    defectRate: (json['defectRate'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'batchCode': batchCode,
    'facilityId': int.parse(facilityId),
    'mushroomId': int.parse(mushroomId),
    'status': status.name.toUpperCase(),
    'substrateType': substrateType,
    'spawnSource': spawnSource,
    'bagQuantity': bagQuantity,
    'startDate': startDate.toIso8601String(),
    'expectedHarvestDate': expectedHarvestDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'actualYieldKg': actualYieldKg,
    'defectRate': defectRate,
    'notes': notes,
  };
}
