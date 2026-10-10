class MushroomCatalogItem {
  final String name;
  final String scientificName;
  final bool isPoisonous;
  final String? edibilityStatus;
  String get edibilityLabel => switch(edibilityStatus) {
    'CHOICE' => 'Ăn ngon', 'EDIBLE' => 'Ăn được', 'INEDIBLE' => 'Không ăn được',
    'POISONOUS' => 'Có độc', 'DEADLY' => 'Độc chết người', _ => isPoisonous ? 'Có độc' : 'Chưa xác định',
  };

  /// Ảnh đại diện do backend trả về (tuỳ chọn). Có thể là URL đầy đủ
  /// (https://...) hoặc đường dẫn tương đối (/media/mushrooms/abc.jpg).
  final String? imageUrl;

  const MushroomCatalogItem({
    required this.name,
    required this.scientificName,
    required this.isPoisonous,
    this.edibilityStatus,
    this.imageUrl,
  });

  /// Khoá để tìm ảnh đóng gói sẵn trong app: tên khoa học viết thường,
  /// ký tự lạ thành "_". VD: "Auricularia auricula-judae"
  /// -> assets/mushrooms/auricularia_auricula_judae.jpg
  String get assetKey => scientificName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  factory MushroomCatalogItem.fromJson(Map<String, dynamic> json) {
    final rawImage = (json['image_url'] ?? json['image'] ?? json['thumbnail'])
        ?.toString()
        .trim();
    return MushroomCatalogItem(
      name: (json['name'] ?? '').toString(),
      scientificName: (json['scientific_name'] ?? json['name'] ?? '').toString(),
      isPoisonous: json['is_poisonous'] == true ||
          json['is_poisonous'] == 1 ||
          json['is_poisonous'].toString().toLowerCase() == 'true',
      imageUrl: (rawImage == null || rawImage.isEmpty) ? null : rawImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientific_name': scientificName,
      'is_poisonous': isPoisonous,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}

class MushroomCatalogResponse {
  final String source;
  final int total;
  final int poisonousCount;
  final int safeCount;
  final List<MushroomCatalogItem> mushrooms;
  final List<MushroomCatalogItem> poisonousMushrooms;

  const MushroomCatalogResponse({
    required this.source,
    required this.total,
    required this.poisonousCount,
    required this.safeCount,
    required this.mushrooms,
    required this.poisonousMushrooms,
  });

  factory MushroomCatalogResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['mushrooms'] as List<dynamic>? ?? [])
        .map((e) => MushroomCatalogItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final poisonousList = (json['poisonous_mushrooms'] as List<dynamic>? ?? [])
        .map((e) => MushroomCatalogItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return MushroomCatalogResponse(
      source: (json['source'] ?? 'mushroom_dataset').toString(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
      poisonousCount: (json['poisonous_count'] as num?)?.toInt() ??
          list.where((m) => m.isPoisonous).length,
      safeCount: (json['safe_count'] as num?)?.toInt() ??
          list.where((m) => !m.isPoisonous).length,
      mushrooms: list,
      poisonousMushrooms: poisonousList.isNotEmpty
          ? poisonousList
          : list.where((m) => m.isPoisonous).toList(),
    );
  }
}

final mockCatalogResponse = MushroomCatalogResponse(
  source: 'mushroom_dataset_v1',
  total: 16,
  poisonousCount: 6,
  safeCount: 10,
  mushrooms: const [
    MushroomCatalogItem(
      name: 'Nấm Rơm (Straw Mushroom)',
      scientificName: 'Volvariella volvacea',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Bào Ngư (Oyster Mushroom)',
      scientificName: 'Pleurotus ostreatus',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Linh Chi (Lingzhi)',
      scientificName: 'Ganoderma lucidum',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Mèo / Mộc Nhĩ (Wood Ear)',
      scientificName: 'Auricularia auricula-judae',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Mỡ (Button Mushroom)',
      scientificName: 'Agaricus bisporus',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Đùi Gà (King Oyster)',
      scientificName: 'Pleurotus eryngii',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Kim Châm (Enoki)',
      scientificName: 'Flammulina velutipes',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Hương / Đông Cô (Shiitake)',
      scientificName: 'Lentinula edodes',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Mối (Termitomyces)',
      scientificName: 'Termitomyces albuminosus',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Tràm (Tylopilus)',
      scientificName: 'Tylopilus felleus',
      isPoisonous: false,
    ),
    MushroomCatalogItem(
      name: 'Nấm Tử Thần (Death Cap)',
      scientificName: 'Amanita phalloides',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Tán Bay (Fly Agaric)',
      scientificName: 'Amanita muscaria',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Độc Tán Trắng (Destroying Angel)',
      scientificName: 'Amanita verna',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Độc Mũ Khía Nâu (Inocybe)',
      scientificName: 'Inocybe rimosa',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Ô Tán Trắng Độc (False Parasol)',
      scientificName: 'Chlorophyllum molybdites',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Độc Ma (Omphalotus)',
      scientificName: 'Omphalotus olearius',
      isPoisonous: true,
    ),
  ],
  poisonousMushrooms: const [
    MushroomCatalogItem(
      name: 'Nấm Tử Thần (Death Cap)',
      scientificName: 'Amanita phalloides',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Tán Bay (Fly Agaric)',
      scientificName: 'Amanita muscaria',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Độc Tán Trắng (Destroying Angel)',
      scientificName: 'Amanita verna',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Độc Mũ Khía Nâu (Inocybe)',
      scientificName: 'Inocybe rimosa',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Ô Tán Trắng Độc (False Parasol)',
      scientificName: 'Chlorophyllum molybdites',
      isPoisonous: true,
    ),
    MushroomCatalogItem(
      name: 'Nấm Độc Ma (Omphalotus)',
      scientificName: 'Omphalotus olearius',
      isPoisonous: true,
    ),
  ],
);

