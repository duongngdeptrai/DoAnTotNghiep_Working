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
      final uri = Uri.parse(wsUrl);
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
        },
        onDone: () {
          _status = SocketStatus.disconnected;
          _statusController.add(_status);
        },
      );

      _status = SocketStatus.connected;
      _statusController.add(_status);
    } catch (error) {
      _status = SocketStatus.error;
      _statusController.add(_status);
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _status = SocketStatus.disconnected;
    _statusController.add(_status);
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _status == SocketStatus.connected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }
}