import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';

enum SocketStatus { disconnected, connecting, connected, error }

class SocketService {
  final String wsUrl;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  SocketStatus _status = SocketStatus.disconnected;
  final List<Map<String, dynamic>> _messages = [];

  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _initialDelayMs = 1000;
  static const int _maxDelayMs = 30000;
  Timer? _reconnectTimer;

  final StreamController<SocketStatus> _statusController = StreamController<SocketStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();

  SocketService(this.wsUrl, this.token);

  SocketStatus get status => _status;
  Stream<SocketStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Map<String, dynamic>? get latestMessage => _messages.isNotEmpty ? _messages.first : null;

  Future<void> connect() async {
    _status = SocketStatus.connecting;
    _statusController.add(_status);

    try {
      final uri = Uri.parse(wsUrl).replace(queryParameters: {'token': token});
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String);
            _messages.insert(0, message);
            if (_messages.length > 10) _messages.removeLast();
            _messageController.add(message);
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          _status = SocketStatus.error;
          _statusController.add(_status);
          _scheduleReconnect();
        },
        onDone: () {
          if (_status != SocketStatus.disconnected) {
            _scheduleReconnect();
          }
        },
      );

      _status = SocketStatus.connected;
      _reconnectAttempt = 0;
      _statusController.add(_status);
    } catch (error) {
      _status = SocketStatus.error;
      _statusController.add(_status);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _status = SocketStatus.error;
      _statusController.add(_status);
      return;
    }
    final delay = (_initialDelayMs * (1 << _reconnectAttempt))
        .clamp(_initialDelayMs, _maxDelayMs);
    _reconnectAttempt++;
    _status = SocketStatus.disconnected;
    _statusController.add(_status);
    _reconnectTimer = Timer(Duration(milliseconds: delay), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _status = SocketStatus.disconnected;
    _statusController.add(_status);
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _status == SocketStatus.connected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }
}
