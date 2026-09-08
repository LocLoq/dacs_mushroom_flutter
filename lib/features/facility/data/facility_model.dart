enum FacilityStatus { active, paused, maintenance }

class FacilityModel {
  final String id;
  final String name;
  final String address;
  final FacilityStatus status;

  FacilityModel({
    required this.id,
    required this.name,
    required this.address,
    required this.status,
  });

  // TODO(BACKEND): factory FacilityModel.fromJson(Map<String, dynamic> json) => FacilityModel(
  //   id: json['id'].toString(),
  //   name: json['name'],
  //   address: json['address'],
  //   status: FacilityStatus.values.byName(json['status']),
  // );
}

// ------ Mock data (thay bằng dữ liệu thật từ ApiClient) ------
final mockFacilities = [
  FacilityModel(id: '1', name: 'Trại nấm Đơn Dương', address: 'Đơn Dương, Lâm Đồng', status: FacilityStatus.active),
  FacilityModel(id: '2', name: 'Trại nấm Đức Trọng', address: 'Đức Trọng, Lâm Đồng', status: FacilityStatus.maintenance),
  FacilityModel(id: '3', name: 'Trại nấm Lạc Dương', address: 'Lạc Dương, Lâm Đồng', status: FacilityStatus.paused),
];
