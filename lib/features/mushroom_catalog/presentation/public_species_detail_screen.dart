import 'package:flutter/material.dart';
import '../../../core/network/farm_api.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/net_image.dart';
import '../../gallery/entity_gallery.dart';

class PublicSpeciesDetailScreen extends StatelessWidget {
  const PublicSpeciesDetailScreen({
    super.key,
    required this.speciesId,
    this.api,
  });
  final int speciesId;
  final FarmApi? api;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết giống nấm')),
    body: FutureBody<J>(
      load: () async =>
          (await (api ?? FarmApi.instance).get(
            '/mushroom-species/$speciesId',
            public: true,
          )).m('data') ??
          {},
      builder: (ctx, data, reload) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          NetImage(
            data.sn('coverImageUrl') ?? data.sn('imageUrl'),
            height: 200,
            authenticated: false,
          ),
          const SizedBox(height: 16),
          Text(
            data.s('commonName'),
            style: Theme.of(ctx).textTheme.headlineSmall,
          ),
          Text(
            data.s('scientificName'),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          InfoRow(
            'Khả năng ăn',
            label(edibilityLabels, data.sn('edibilityStatus')),
          ),
          InfoRow('Tên gọi khác', data.sn('otherNames')),
          InfoRow('Họ / Chi', '${data.s('family')} / ${data.s('genus')}'),
          InfoRow('Mũ nấm', data.sn('capDescription')),
          InfoRow('Phiến nấm', data.sn('gillsDescription')),
          InfoRow('Thân nấm', data.sn('stemDescription')),
          InfoRow('Màu bào tử', data.sn('sporePrintColor')),
          InfoRow('Phản ứng khi dập', data.sn('bruisingBehavior')),
          InfoRow(
            'Kiểu sinh thái',
            label(ecologyLabels, data.sn('ecologyType')),
          ),
          InfoRow('Môi trường sống', data.sn('habitat')),
          InfoRow('Mùa ra quả thể', data.sn('fruitingSeason')),
          InfoRow('Triệu chứng ngộ độc', data.sn('toxicitySymptoms')),
          InfoRow('Dược tính', data.sn('medicinalProperties')),
          InfoRow(
            'Độ khó nuôi',
            label(difficultyLabels, data.sn('cultivationDifficulty')),
          ),
          const SizedBox(height: 20),
          EntityGallery(
            resource: 'mushroom-species',
            parentId: speciesId,
            canEdit: false,
            publicView: true,
            api: api,
          ),
        ],
      ),
    ),
  );
}
