import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ritual_room/data/datasources/interaction_api.dart';
import '../../features/ritual_room/data/datasources/mock_interaction_api.dart';
import '../../features/ritual_room/data/datasources/mock_ritual_content_api.dart';
import '../../features/ritual_room/data/datasources/ritual_content_api.dart';
import '../../features/ritual_room/data/mappers/interaction_mapper.dart';
import '../../features/ritual_room/data/mappers/ritual_room_mapper.dart';
import '../../features/ritual_room/data/repositories/interaction_repository_impl.dart';
import '../../features/ritual_room/data/repositories/ritual_room_repository_impl.dart';
import '../../features/ritual_room/domain/repositories/interaction_repository.dart';
import '../../features/ritual_room/domain/repositories/ritual_room_repository.dart';
import 'interaction_engine_providers.dart';

final interactionMapperProvider = Provider<InteractionMapper>(
  (ref) => const InteractionMapper(),
);

final ritualRoomMapperProvider = Provider<RitualRoomMapper>(
  (ref) => const RitualRoomMapper(),
);

final ritualContentApiProvider = Provider<RitualContentApi>(
  (ref) => MockRitualContentApi(),
);

final ritualRoomRepositoryProvider = Provider<RitualRoomRepository>(
  (ref) => RitualRoomRepositoryImpl(
    api: ref.watch(ritualContentApiProvider),
    mapper: ref.watch(ritualRoomMapperProvider),
  ),
);

final interactionApiProvider = Provider<InteractionApi>(
  (ref) => MockInteractionApi(
    engine: ref.watch(interactionEnginePortProvider),
    mapper: ref.watch(interactionMapperProvider),
  ),
);

final interactionRepositoryProvider = Provider<InteractionRepository>(
  (ref) => InteractionRepositoryImpl(
    api: ref.watch(interactionApiProvider),
    mapper: ref.watch(interactionMapperProvider),
  ),
);
