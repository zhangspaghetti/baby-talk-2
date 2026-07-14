import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ritual_room/presentation/capability/interaction_capability_mask.dart';

final interactionCapabilityMaskProvider = Provider<InteractionCapabilityMask>(
  (ref) => InteractionCapabilityMask.phase41,
);
