class StrainModel {
  final String id;
  final String name;
  final double tempMin, tempMax; // °C
  final double humidityMin, humidityMax; // %
  final double co2Min, co2Max; // ppm

  StrainModel({
    required this.id,
    required this.name,
    required this.tempMin,
    required this.tempMax,
    required this.humidityMin,
    required this.humidityMax,
    required this.co2Min,
    required this.co2Max,
  });

  // TODO(BACKEND): factory StrainModel.fromJson(...) / Map<String,dynamic> toJson()
}

// ------ Mock data (thay bằng dữ liệu thật từ ApiClient) ------
final mockStrains = [
  StrainModel(id: '1', name: 'Nấm Bào Ngư', tempMin: 25, tempMax: 30, humidityMin: 80, humidityMax: 95, co2Min: 400, co2Max: 800),
  StrainModel(id: '2', name: 'Nấm Linh Chi', tempMin: 22, tempMax: 28, humidityMin: 85, humidityMax: 95, co2Min: 500, co2Max: 1000),
  StrainModel(id: '3', name: 'Nấm Rơm', tempMin: 28, tempMax: 35, humidityMin: 80, humidityMax: 90, co2Min: 400, co2Max: 700),
];
