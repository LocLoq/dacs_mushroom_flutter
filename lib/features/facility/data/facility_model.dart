enum FacilityStatus { active, suspended, closed }

class FacilityModel {
  final String id, name, address;
  final FacilityStatus status;
  const FacilityModel({
    required this.id,
    required this.name,
    required this.address,
    required this.status,
  });
  factory FacilityModel.fromJson(Map<String, dynamic> json) => FacilityModel(
    id: json['id'].toString(),
    name: json['name'] as String,
    address: json['address'] as String,
    status: FacilityStatus.values.byName(
      (json['status'] as String).toLowerCase(),
    ),
  );
}
