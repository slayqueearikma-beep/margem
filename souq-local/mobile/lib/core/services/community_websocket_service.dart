import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/community_models.dart';
import 'api_service.dart';

typedef CommunityWsHandler = void Function(Map<String, dynamic> event);

enum CommunityWsConnectionState { disconnected, connecting, connected, reconnecting }

class CommunityWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _channelId;
  String? _citySlug;
  CommunityWsHandler? _onEvent;
  void Function(Object error)? _onError;
  int _reconnectAttempt = 0;
  final _stateController = StreamController<CommunityWsConnectionState>.broadcast();

  Stream<CommunityWsConnectionState> get connectionState => _stateController.stream;
  CommunityWsConnectionState _state = CommunityWsConnectionState.disconnected;

  String _wsPath = '/community/ws';
  Map<String, String> _extraQueryParams = const {};

  Future<void> connect({
    required String channelId,
    required Future<String> Function() fetchTicket,
    required String citySlug,
    required CommunityWsHandler onEvent,
    void Function(Object error)? onError,
    String wsPath = '/community/ws',
    Map<String, String> extraQueryParams = const {},
  }) async {
    disconnect(notify: false);
    _channelId = channelId;
    _citySlug = citySlug;
    _wsPath = wsPath;
    _extraQueryParams = extraQueryParams;
    _onEvent = onEvent;
    _onError = onError;
    _setState(CommunityWsConnectionState.connecting);
    try {
      final ticket = await fetchTicket();
      final base = AppConfig.apiBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$base$_wsPath').replace(
        queryParameters: {
          'channel_id': channelId,
          'ticket': ticket,
          if (citySlug.isNotEmpty) 'city_slug': citySlug,
          ..._extraQueryParams,
        },
      );
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );
      _reconnectAttempt = 0;
      _setState(CommunityWsConnectionState.connected);
      _startPing();
    } catch (error) {
      _handleError(error);
    }
  }

  void _handleMessage(dynamic data) {
    if (data == '{"type":"pong"}') return;
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      _onEvent?.call(decoded);
    } catch (_) {}
  }

  void _handleError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 401 || error.statusCode == 403)) {
      disconnect();
      _onError?.call(error);
      return;
    }
    _onError?.call(error);
    _scheduleReconnect();
  }

  void _handleDone() {
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_channelId == null || _citySlug == null || _onEvent == null) return;
    _stopPing();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _setState(CommunityWsConnectionState.reconnecting);
    final delay = Duration(
      seconds: [1, 2, 4, 8, 15, 30][_reconnectAttempt.clamp(0, 5)],
    );
    _reconnectAttempt += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      final fetchTicket = _ticketFetcher;
      if (fetchTicket == null) return;
      connect(
        channelId: _channelId!,
        fetchTicket: fetchTicket,
        citySlug: _citySlug!,
        onEvent: _onEvent!,
        onError: _onError,
        wsPath: _wsPath,
        extraQueryParams: _extraQueryParams,
      );
    });
  }

  Future<String> Function()? _ticketFetcher;

  void setTicketFetcher(Future<String> Function() fetchTicket) {
    _ticketFetcher = fetchTicket;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) => ping());
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void sendTyping() {
    _channel?.sink.add('typing:1');
  }

  void ping() {
    _channel?.sink.add('ping');
  }

  void disconnect({bool notify = true}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopPing();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    if (notify) {
      _channelId = null;
      _citySlug = null;
      _onEvent = null;
      _onError = null;
      _ticketFetcher = null;
      _reconnectAttempt = 0;
      _setState(CommunityWsConnectionState.disconnected);
    }
  }

  void _setState(CommunityWsConnectionState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  bool get isConnected => _state == CommunityWsConnectionState.connected;
  String? get channelId => _channelId;
  CommunityWsConnectionState get state => _state;

  void dispose() {
    disconnect();
    _stateController.close();
  }
}

CommunityMessageModel? parseWsMessage(Map<String, dynamic> event) {
  if (event['type'] != 'message.new') return null;
  final payload = event['payload'];
  if (payload is! Map<String, dynamic>) return null;
  return CommunityMessageModel.fromJson(payload);
}
