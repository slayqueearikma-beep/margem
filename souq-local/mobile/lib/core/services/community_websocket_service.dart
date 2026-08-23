import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/community_models.dart';

typedef CommunityWsHandler = void Function(Map<String, dynamic> event);

class CommunityWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _channelId;

  void connect({
    required String channelId,
    required String token,
    required String citySlug,
    required CommunityWsHandler onEvent,
    void Function(Object error)? onError,
  }) {
    disconnect();
    _channelId = channelId;

    final base = AppConfig.apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$base/community/ws').replace(
      queryParameters: {
        'channel_id': channelId,
        'token': token,
        'city_slug': citySlug,
      },
    );

    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      (data) {
        if (data == '{"type":"pong"}') return;
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          onEvent(decoded);
        } catch (_) {}
      },
      onError: onError,
    );
  }

  void sendTyping() {
    _channel?.sink.add('typing:1');
  }

  void ping() {
    _channel?.sink.add('ping');
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _channelId = null;
  }

  bool get isConnected => _channel != null;
  String? get channelId => _channelId;
}

/// Parse a WebSocket message.new payload into [CommunityMessageModel].
CommunityMessageModel? parseWsMessage(Map<String, dynamic> event) {
  if (event['type'] != 'message.new') return null;
  final payload = event['payload'];
  if (payload is! Map<String, dynamic>) return null;
  return CommunityMessageModel.fromJson(payload);
}
