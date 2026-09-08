class MushroomCatalogItem {
  final String name;
  final String scientificName;
  final bool isPoisonous;

  const MushroomCatalogItem({
    required this.name,
    required this.scientificName,
    required this.isPoisonous,
  });

  factory MushroomCatalogItem.fromJson(Map<String, dynamic> json) {
    return MushroomCatalogItem(
      name: (json['name'] ?? '').toString(),
      scientificName: (json['scientific_name'] ?? json['name'] ?? '').toString(),
      isPoisonous: json['is_poisonous'] == true ||
          json['is_poisonous'] == 1 ||
          json['is_poisonous'].toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientific_name': scientificName,
      'is_poisonous': isPoisonous,
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

