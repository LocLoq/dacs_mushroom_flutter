class StrainModel {
  final String id, name, scientificName, family, genus, edibilityStatus;
  final String? habitat, cultivationDifficulty, imageUrl;
  const StrainModel({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.family,
    required this.genus,
    required this.edibilityStatus,
    this.habitat,
    this.cultivationDifficulty,
    this.imageUrl,
  });
  factory StrainModel.fromJson(Map<String, dynamic> json) => StrainModel(
    id: json['id'].toString(),
    name: json['commonName'] as String,
    scientificName: json['scientificName'] as String,
    family: json['family'] as String,
    genus: json['genus'] as String,
    edibilityStatus: json['edibilityStatus'] as String,
    habitat: json['habitat'] as String?,
    cultivationDifficulty: json['cultivationDifficulty'] as String?,
    imageUrl: json['imageUrl'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'commonName': name,
    'scientificName': scientificName,
    'family': family,
    'genus': genus,
    'edibilityStatus': edibilityStatus,
    'habitat': habitat,
    'cultivationDifficulty': cultivationDifficulty,
    'imageUrl': imageUrl,
  };
}
