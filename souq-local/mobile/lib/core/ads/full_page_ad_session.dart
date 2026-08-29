import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks full-page ad fetch attempts and shown campaigns for the current app session.
final fullPageAdAttemptedProvider = StateProvider<bool>((ref) => false);

final fullPageAdShownCampaignIdsProvider =
    StateProvider<Set<String>>((ref) => const {});
