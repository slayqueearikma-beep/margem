import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keep an autoDispose provider alive briefly after the last listener disposes.
void retainProviderCache(
  Ref ref, {
  Duration ttl = const Duration(minutes: 30),
}) {
  final link = ref.keepAlive();
  ref.onCancel(() {
    Future<void>.delayed(ttl, link.close);
  });
}
